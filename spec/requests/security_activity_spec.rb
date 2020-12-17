RSpec.describe "security activities" do
  let(:user) { FactoryBot.create(:user) }

  it "records ACCOUNT_LOCKED events" do
    (Devise.maximum_attempts + 1).times do
      post new_user_session_path, params: { "user[email]" => user.email, "user[password]" => "incorrect" }
    end

    expect_event SecurityActivity::ACCOUNT_LOCKED
  end

  it "records MANUAL_ACCOUNT_UNLOCK events" do
    unlock_token = user.lock_access!
    get user_unlock_path(unlock_token: unlock_token)

    expect_event SecurityActivity::MANUAL_ACCOUNT_UNLOCK
  end

  context "with MFA enabled" do
    before { allow(Rails.configuration).to receive(:feature_flag_mfa).and_return(true) }

    it "records ADDITIONAL_FACTOR_VERIFICATION_SUCCESS events" do
      post new_user_session_path, params: { "user[email]" => user.email, "user[password]" => user.password }
      post user_session_phone_verify_path, params: { "phone_code" => user.reload.phone_code }

      expect_event SecurityActivity::ADDITIONAL_FACTOR_VERIFICATION_SUCCESS, factor: :sms
    end

    it "records ADDITIONAL_FACTOR_VERIFICATION_FAILURE events" do
      post new_user_session_path, params: { "user[email]" => user.email, "user[password]" => user.password }
      post user_session_phone_verify_path, params: { "phone_code" => "incorrect" }

      expect_event SecurityActivity::ADDITIONAL_FACTOR_VERIFICATION_FAILURE, factor: :sms
    end
  end

  it "records LOGIN_SUCCESS events" do
    post new_user_session_path, params: { "user[email]" => user.email, "user[password]" => user.password }

    expect_event SecurityActivity::LOGIN_SUCCESS
  end

  it "records LOGIN_FAILURE events" do
    post new_user_session_path, params: { "user[email]" => user.email }
    post response.redirect_url, params: { "user[email]" => user.email, "user[password]" => "incorrect" }

    expect_event SecurityActivity::LOGIN_FAILURE
  end

  it "records PASSWORD_RESET_REQUEST events" do
    post create_password_path, params: { "user[email]" => user.email }

    expect_event SecurityActivity::PASSWORD_RESET_REQUEST
  end

  it "records PASSWORD_RESET_SUCCESS events" do
    post user_password_path, params: {
      "_method" => "put",
      "user[password]" => "new-password",
      "user[password_confirmation]" => "new-password",
      "user[reset_password_token]" => user.send_reset_password_instructions,
    }

    expect_event SecurityActivity::PASSWORD_RESET_SUCCESS
  end

  context "with a user logged in" do
    before { sign_in user }

    context "with an OAuth application" do
      let(:application) do
        FactoryBot.create(
          :oauth_application,
          name: "name",
          redirect_uri: "http://localhost",
          scopes: %i[openid],
        )
      end

      it "records LOGIN_SUCCESS events for OAuth authorizations" do
        get authorization_endpoint_url(client: application, scope: "openid")

        expect_event SecurityActivity::LOGIN_SUCCESS, application: application
      end
    end

    it "records EMAIL_CHANGE_REQUESTED events" do
      post user_registration_path, params: {
        "_method" => "put",
        "user[email]" => "new-email-address@example.com",
        "user[current_password]" => user.password,
      }

      expect_event SecurityActivity::EMAIL_CHANGE_REQUESTED, notes: "from #{user.email} to #{user.reload.unconfirmed_email}"
    end

    context "with MFA enabled" do
      before { allow(Rails.configuration).to receive(:feature_flag_mfa).and_return(true) }

      it "records PHONE_CHANGED events" do
        old_phone = user.phone

        post edit_user_registration_phone_code_path, params: {
          "phone" => "07581123456",
          "current_password" => user.password,
        }
        post edit_user_registration_phone_verify_path, params: { "phone_code" => user.phone_code }

        expect_event SecurityActivity::PHONE_CHANGED, notes: "from #{old_phone} to #{user.reload.phone}"
      end
    end

    it "records PASSWORD_CHANGED events" do
      post user_registration_path, params: {
        "_method" => "put",
        "user[password]" => "new-password",
        "user[password_confirmation]" => "new-password",
        "user[current_password]" => user.password,
      }

      expect_event SecurityActivity::PASSWORD_CHANGED
    end
  end

  it "records EMAIL_CHANGED events" do
    get user_confirmation_path(confirmation_token: user.confirmation_token)

    expect_event SecurityActivity::EMAIL_CHANGED, notes: "to #{user.email}"
  end

  def expect_event(event, application: nil, factor: nil, notes: nil)
    events = user.security_activities.of_type(event)
    events = events.where(oauth_application_id: application.id) if application
    events = events.where(factor: factor) if factor
    events = events.where(notes: notes) if notes

    expect(events.count).to_not eq(0)
  end
end
