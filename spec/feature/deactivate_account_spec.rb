RSpec.feature "Deactivate account by flag" do

  context "For an unauthenticated session" do
    scenario "A user sees a sevice deactivated message when trying to log in" do
      given_accounts_are_disabled_by_feature_flag do
        when_i_visit_the_login_page
        then_i_see_account_disabled_page_content
      end
    end

    scenario "A user sees a sevice deactivated message when trying to sign up" do
      given_accounts_are_disabled_by_feature_flag do
        when_i_visit_the_signup_page
        then_i_see_account_disabled_page_content
      end
    end

    scenario "A user sees a sevice deactivated message when trying to leave feedback" do
      given_accounts_are_disabled_by_feature_flag do
        and_i_visit_the_feedback_page
        then_i_see_account_disabled_page_content
      end
    end
  end

  context "For an authenticated session" do
    scenario "A user is logged out and sees a service deactivated message when visiting the account root page" do
      given_accounts_are_disabled_by_feature_flag do
        given_i_am_logged_in
        when_i_visit_the_account_root_page
        then_i_see_account_disabled_page_content
      end
    end

    scenario "A user is logged out and sees a service deactivated message when visiting the manage account page" do
      given_accounts_are_disabled_by_feature_flag do
        given_i_am_logged_in
        when_i_visit_the_manage_page
        then_i_see_account_disabled_page_content
      end
    end

    scenario "A user is logged out and sees a service deactivated message when visiting the account security page" do
      given_accounts_are_disabled_by_feature_flag do
        given_i_am_logged_in
        when_i_visit_the_security_page
        then_i_see_account_disabled_page_content
      end
    end

    scenario "A user is logged out and sees a service deactivated message when visiting the give feedback page" do
      given_accounts_are_disabled_by_feature_flag do
        given_i_am_logged_in
        when_i_visit_the_feedback_page
        then_i_see_account_disabled_page_content
      end
    end
  end

  def given_accounts_are_disabled_by_feature_flag(&block)
    ClimateControl.modify FEATURE_FLAG_ACCOUNTS: "disabled" do
      block.call
    end
  end

  def given_i_am_logged_in
    user = FactoryBot.create(:user)
    visit new_user_session_path
    fill_in "email", with: user.email
    click_on I18n.t("welcome.show.button.label")
    fill_in "password", with: "abcd1234"
    click_on I18n.t("devise.sessions.new.fields.submit.label")
  end

  def when_i_visit_the_signup_page
    visit new_user_session_path
  end

  def when_i_visit_the_login_page
    visit user_session_path
  end

  def when_i_visit_the_account_root_page
    visit user_root_path
  end

  def when_i_visit_the_security_page
    visit account_security_path
  end

  def when_i_visit_the_manage_page
    visit account_manage_path
  end

  def when_i_visit_the_feedback_page
    visit feedback_form_path
  end

  def then_i_see_account_disabled_page_content
    expect(page).to have_content(I18n.t("account_disabled.heading"))
    expect(page).to have_content(I18n.t("account_disabled.content"))
  end
end
