RSpec.feature "Remember Me" do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  before { allow(Rails.configuration).to receive(:feature_flag_mfa).and_return(true) }
  before { allow(Rails.configuration).to receive(:feature_flag_bypass_mfa).and_return(bypass_mfa_enabled) }

  let(:bypass_mfa_enabled) { true }

  let!(:user) { FactoryBot.create(:user, :confirmed) }

  context "'remember me' is disabled" do
    let(:bypass_mfa_enabled) { false }

    it "doesn't give the option to 'remember me'" do
      enter_email_address_and_password

      expect(page).to_not have_text(Rails::Html::FullSanitizer.new.sanitize(I18n.t("mfa.phone.code.fields.remember_me.label")))
    end
  end

  context "the user checks 'remember me'" do
    before { log_in_and_remember_me }

    it "shows the event on the security page" do
      visit_security_page

      expect(page).to have_text(I18n.t("account.security.security_codes.code_description.present"))
    end

    context "the user returns 29 days later" do
      before do
        travel(MultiFactorAuth::BYPASS_TOKEN_EXPIRATION_AGE - 1.day)
        enter_email_address_and_password
      end

      it "skips MFA" do
        expect(page).to have_text(I18n.t("account.your_account.heading"))
      end

      it "re-does MFA when changing email address" do
        visit_change_email_page
        expect(page).to have_text(I18n.t("mfa.phone.code.redo_description_preamble"))
      end

      it "re-does MFA when changing password" do
        visit_change_password_page
        expect(page).to have_text(I18n.t("mfa.phone.code.redo_description_preamble"))
      end

      it "re-does MFA when changing phone number" do
        visit_change_number_page
        expect(page).to have_text(I18n.t("mfa.phone.code.redo_description_preamble"))
      end
    end

    context "the user returns 31 days later" do
      before do
        travel(MultiFactorAuth::BYPASS_TOKEN_EXPIRATION_AGE + 1.day)
        enter_email_address_and_password
      end

      it "does not skip MFA" do
        expect(page).to have_text(I18n.t("mfa.phone.code.sign_in_heading"))
      end
    end

    context "with multiple users on the same machine" do
      let(:user2) { FactoryBot.create(:user, email: "other-user@example.com") }

      before do
        travel(Devise.timeout_in + 1.second)
        log_in_and_remember_me(the_user: user2)
        travel(Devise.timeout_in + 1.second)
      end

      it "remembers the first user" do
        enter_email_address_and_password(the_user: user)
        expect(page).to have_text(I18n.t("account.your_account.heading"))
      end

      it "remembers the second user" do
        enter_email_address_and_password(the_user: user2)
        expect(page).to have_text(I18n.t("account.your_account.heading"))
      end
    end
  end

  def enter_email_address_and_password(the_user: user)
    visit new_user_session_path
    fill_in "email", with: the_user.email
    fill_in "password", with: the_user.password
    click_on I18n.t("devise.sessions.new.fields.submit.label")
  end

  def log_in_and_remember_me(the_user: user)
    enter_email_address_and_password(the_user: the_user)
    expect(page).to have_text(Rails::Html::FullSanitizer.new.sanitize(I18n.t("mfa.phone.code.fields.remember_me.label")))

    fill_in "phone_code", with: the_user.reload.phone_code
    check "remember_me"
    click_on I18n.t("mfa.phone.code.fields.submit.label")

    expect(page).to have_text(I18n.t("account.your_account.heading"))
  end

  def visit_security_page
    click_on I18n.t("navigation.menu_bar.security.link_text")
  end

  def visit_change_email_page
    within ".accounts-menu" do
      click_on "Manage your account"
    end
    within "#main-content" do
      click_on "Change Email"
    end
  end

  def visit_change_password_page
    within ".accounts-menu" do
      click_on "Manage your account"
    end
    within "#main-content" do
      click_on "Change Password"
    end
  end

  def visit_change_number_page
    within ".accounts-menu" do
      click_on "Manage your account"
    end
    within "#main-content" do
      click_on "Change Mobile number"
    end
  end
end
