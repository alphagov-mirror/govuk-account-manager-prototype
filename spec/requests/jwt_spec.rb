RSpec.describe "JWT (register and login)" do
  include ActiveJob::TestHelper

  let(:application) do
    FactoryBot.create(
      :oauth_application,
      name: "name",
      redirect_uri: "http://localhost",
      scopes: application_scopes,
    )
  end

  let(:application_scopes) { %i[test_scope_read test_scope_write] }

  let(:private_key) do
    private_key = OpenSSL::PKey::EC.new "prime256v1" # pragma: allowlist secret
    private_key.generate_key
  end

  let(:public_key) { OpenSSL::PKey::EC.new private_key }

  let(:application_key) do
    ApplicationKey.create!(
      application_uid: application.uid,
      key_id: SecureRandom.uuid,
      pem: public_key.to_pem,
    )
  end

  let(:jwt_uid) { application.uid }
  let(:jwt_key) { application_key.key_id }
  let(:jwt_scopes) { %i[test_scope_write] }
  let(:jwt_attributes) { { test: "value" } }
  let(:jwt_post_login_oauth) { "#{Rails.application.config.redirect_base_url}/oauth/authorize?some-query-string" }
  let(:jwt_signing_key) { private_key }

  let(:jwt) do
    payload = { uid: jwt_uid, key: jwt_key, scopes: jwt_scopes, attributes: jwt_attributes, post_login_oauth: jwt_post_login_oauth }.compact
    JWT.encode payload.compact, jwt_signing_key, "ES256"
  end

  context "register" do
    let(:params) do
      {
        "user[email]" => email,
        "user[password]" => password,
        "user[password_confirmation]" => password,
        "email_decision" => email_decision,
        "jwt" => jwt,
      }.compact
    end

    let(:email) { "email@example.com" }
    let(:password) { "abcd1234" } # pragma: allowlist secret
    let(:email_decision) { nil }

    it "creates an access token" do
      post new_user_registration_post_path, params: params
      follow_redirect!
      expect(response).to be_successful

      token = Doorkeeper::AccessToken.last
      expect(token).to_not be_nil
      expect(token.resource_owner_id).to eq(User.last.id)
      expect(token.application.uid).to eq(jwt_uid)
      expect(token.expires_in).to eq(Doorkeeper.config.access_token_expires_in)
      expect(token.scopes).to eq(jwt_scopes)
    end

    it "updates the attributes" do
      post new_user_registration_post_path, params: params
      follow_redirect!
      expect(response).to be_successful

      assert_enqueued_jobs 1, only: SetAttributesJob
    end

    context "no scopes are requested" do
      let(:jwt_scopes) { [] }
      let(:jwt_attributes) { {} }

      it "does not create an access token" do
        expect {
          post new_user_registration_post_path, params: params
          follow_redirect!
          expect(response).to be_successful
        }.to_not(change { Doorkeeper::AccessToken.count })
      end
    end

    context "the user is not persisted" do
      let(:password) { "" }

      it "does not create an access token" do
        expect {
          post new_user_registration_post_path, params: params
          expect(response).to be_successful
        }.to_not(change { Doorkeeper::AccessToken.count })
      end
    end

    context "there's an email topic" do
      let(:application_scopes) { %i[transition_checker] }
      let(:jwt_scopes) { %i[transition_checker] }
      let(:jwt_attributes) { { transition_checker_state: { email_topic_slug: email_topic_slug } } }
      let(:email_topic_slug) { "foo" }

      it "asks if the user would like email notifications" do
        post new_user_registration_post_path, params: params
        expect(response).to be_successful
        expect(response.body).to have_content(I18n.t("devise.registrations.new.needs_email_decision.unsubscribe"))
      end

      context "the user does want notifications" do
        let(:email_decision) { "yes" }

        it "shows the post-registration page" do
          post new_user_registration_post_path, params: params
          follow_redirect!
          expect(response).to be_successful
          expect(response.body).to_not have_content(I18n.t("devise.registrations.new.needs_email_decision.unsubscribe"))
        end

        it "creates the subscription" do
          post new_user_registration_post_path, params: params
          follow_redirect!
          expect(response).to be_successful

          expect(User.last.email_subscriptions.last&.topic_slug).to eq(email_topic_slug)
        end
      end

      context "the user does not want notifications" do
        let(:email_decision) { "no" }

        it "shows the post-registration page" do
          post new_user_registration_post_path, params: params
          follow_redirect!
          expect(response).to be_successful
          expect(response.body).to_not have_content(I18n.t("devise.registrations.new.needs_email_decision.unsubscribe"))
        end

        it "does not create the subscription" do
          expect {
            post new_user_registration_post_path, params: params
            follow_redirect!
            expect(response).to be_successful
          }.to_not(change { EmailSubscription.count })
        end
      end

      context "the user gives something other than 'yes' or 'no' for notifications" do
        let(:email_decision) { "foo" }

        it "shows the post-registration page" do
          post new_user_registration_post_path, params: params
          expect(response).to be_successful
          expect(response.body).to have_content(I18n.t("activerecord.errors.models.user.attributes.email_decision.invalid"))
        end
      end
    end

    context "if the user auths through the application again" do
      before do
        post new_user_registration_post_path, params: params
      end

      it "doesn't prompt for consent" do
        client = OAuth2::Client.new(application.uid, application.secret, site: "https://example.org")
        uri = client.auth_code.authorize_url(redirect_uri: application.redirect_uri, scope: jwt_scopes.join(" "))
        params = Rack::Utils.parse_nested_query(URI(uri).query)
        get oauth_authorization_path, params: params
        expect(response).to have_http_status(302)
      end

      context "with new scopes" do
        it "prompts for consent" do
          client = OAuth2::Client.new(application.uid, application.secret, site: "https://example.org")
          uri = client.auth_code.authorize_url(redirect_uri: application.redirect_uri, scope: "test_scope_read")
          params = Rack::Utils.parse_nested_query(URI(uri).query)
          get oauth_authorization_path, params: params
          expect(response).to have_http_status(200)
        end
      end
    end
  end

  context "login" do
    let!(:user) do
      FactoryBot.create(
        :user,
        email: email,
        password: password,
        password_confirmation: password,
      )
    end

    let(:params) do
      {
        "user[email]" => email,
        "user[password]" => password,
        "jwt" => jwt,
      }
    end

    let(:email) { "email@example.com" }
    let(:password) { "abcd1234" }

    it "redirects the user to the OAuth consent flow" do
      post user_session_path, params: params
      expect(response).to redirect_to(jwt_post_login_oauth)
    end
  end
end
