RSpec.feature "Registration (coming from another application)" do
  include ActiveJob::TestHelper

  before { allow(Rails.configuration).to receive(:feature_flag_mfa).and_return(true) }

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
    private_key = OpenSSL::PKey::EC.new "prime256v1"
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

  let(:email) { "email@example.com" }
  let(:password) { "abcd1234" }

  it "creates an access token" do
    start_journey

    token = Doorkeeper::AccessToken.last
    expect(token).to_not be_nil
    expect(token.resource_owner_id).to eq(User.last.id)
    expect(token.application.uid).to eq(jwt_uid)
    expect(token.expires_in).to eq(Doorkeeper.config.access_token_expires_in)
    expect(token.scopes).to eq(jwt_scopes)
  end

  it "updates the attributes" do
    start_journey

    assert_enqueued_jobs 1, only: SetAttributesJob
  end

  context "no scopes are requested" do
    let(:jwt_scopes) { [] }
    let(:jwt_attributes) { {} }

    it "does not create an access token" do
      expect {
        start_journey
      }.to_not(change { Doorkeeper::AccessToken.count })
    end
  end

  context "there's an email topic" do
    let(:application_scopes) { %i[transition_checker] }
    let(:jwt_scopes) { %i[transition_checker] }
    let(:jwt_attributes) { { transition_checker_state: { email_topic_slug: email_topic_slug } } }
    let(:email_topic_slug) { "foo" }

    it "asks if the user would like email notifications" do
      start_journey

      expect(page).to have_text(I18n.t("devise.registrations.transition_emails.unsubscribe"))
      expect(page).to_not have_text(I18n.t("activerecord.errors.models.user.attributes.email_decision.invalid"))
    end

    context "the user does want notifications" do
      it "shows the post-registration page" do
        start_journey
        i_want_emails

        expect(page).to_not have_text(I18n.t("devise.registrations.transition_emails.unsubscribe"))
      end

      it "creates the subscription" do
        start_journey
        i_want_emails

        expect(User.last.email_subscriptions.last&.topic_slug).to eq(email_topic_slug)
      end
    end

    context "the user does not want notifications" do
      it "shows the post-registration page" do
        start_journey
        i_do_not_want_emails

        expect(page).to_not have_text(I18n.t("devise.registrations.transition_emails.unsubscribe"))
      end

      it "does not create the subscription" do
        expect {
          start_journey
          i_do_not_want_emails
        }.to_not(change { EmailSubscription.count })
      end
    end

    context "the user doesn't tick either option for notifications" do
      it "shows an error" do
        start_journey
        click_on I18n.t("devise.registrations.transition_emails.fields.submit.label")

        expect(page).to have_text(I18n.t("activerecord.errors.models.user.attributes.email_decision.invalid"))
      end
    end
  end

  context "if the user auths through the application again" do
    before { start_journey }

    it "doesn't prompt for consent" do
      client = OAuth2::Client.new(application.uid, application.secret, site: "https://example.org")
      uri = client.auth_code.authorize_url(redirect_uri: application.redirect_uri, scope: jwt_scopes.join(" "))
      visit "#{oauth_authorization_path}?#{uri.split('?')[1]}"
      expect(page).to_not have_content(I18n.t("doorkeeper.authorizations.new.able_to"))
    end

    context "with new scopes" do
      it "prompts for consent" do
        client = OAuth2::Client.new(application.uid, application.secret, site: "https://example.org")
        uri = client.auth_code.authorize_url(redirect_uri: application.redirect_uri, scope: "test_scope_read")
        visit "#{oauth_authorization_path}?#{uri.split('?')[1]}"
        expect(page).to have_content(I18n.t("doorkeeper.authorizations.new.able_to"))
      end
    end
  end

  context "the user goes part way through the registration process then starts again and completes" do
    it "shows the post-registration page" do
      i_click_from_application
      i_enter_registration_details
      visit new_user_registration_start_path
      i_enter_registration_details
      i_enter_phone_code

      expect(page).to have_text(I18n.t("confirmation_sent.heading"))
    end
  end

  def start_journey
    i_click_from_application
    i_enter_registration_details
    i_enter_phone_code
  end

  def i_click_from_application
    Capybara.current_session.driver.submit :post, welcome_path, {
      "jwt" => jwt,
    }.compact
  end

  def i_enter_registration_details
    fill_in "email", with: email
    fill_in "password", with: password
    fill_in "phone", with: "07958123456"
    click_on I18n.t("devise.registrations.start.fields.submit.label")
  end

  def i_enter_phone_code
    phone_code = RegistrationState.order(:touched_at).last.phone_code
    fill_in "phone_code", with: phone_code
    click_on I18n.t("mfa.phone.code.fields.submit.label")

    i_consent_my_information_being_used
  end

  def i_consent_my_information_being_used
    find(:css, "input[name='cookie_consent'][value='yes']").set(true)
    find(:css, "input[name='feedback_consent'][value='yes']").set(true)
    click_on I18n.t("devise.registrations.your_information.fields.submit.label")
  end

  def i_want_emails
    find_field(I18n.t("devise.registrations.transition_emails.fields.emailsignup.yes")).click
    click_on I18n.t("devise.registrations.transition_emails.fields.submit.label")
  end

  def i_do_not_want_emails
    find_field(I18n.t("devise.registrations.transition_emails.fields.emailsignup.no")).click
    click_on I18n.t("devise.registrations.transition_emails.fields.submit.label")
  end
end
