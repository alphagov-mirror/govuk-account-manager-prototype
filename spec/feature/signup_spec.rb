require "spec_helper"
require "pry"

RSpec.feature "Account Sign up", type: :feature do
  include FeaturesHelper

  context "when arriving from a registered application" do
    let(:private_key) { jwt_private_key }
    let(:public_key) { jwt_public_key(private_key) }

    before do
      register_authorised_application(public_key)
    end

    scenario do
      given_i_arrive_with_a_valid_jwt
      and_i_see_enter_your_email_address_form_heading
      and_i_enter_a_valid_email_address
      and_i_click_continue
      and_i_see_create_password_form_heading
      and_i_enter_a_valid_password
      and_i_enter_an_identical_password_confirmation
      and_i_click_continue
      and_i_see_data_protection_form_heading
      and_i_click_continue
      and_i_see_the_notification_form_heading
      and_i_choose_yes
      and_i_click_continue
      then_i_see_confirm_email_page
      and_i_see_go_to_account_button
    end
  end

  def given_i_arrive_with_a_valid_jwt
    post_jwt_to_root(transition_payload, public_key)
    expect(page.status_code).to eql(200)
  end

  def and_i_see_enter_your_email_address_form_heading
    expect(page).to have_text(I18n.t("welcome.show.heading"))
  end

  def and_i_see_create_password_form_heading
    expect(page).to have_text(I18n.t("devise.registrations.new.needs_password.heading"))
  end

  def and_i_see_data_protection_form_heading
    expect(page).to have_text(I18n.t("devise.registrations.new.needs_consent.heading"))
  end

  def and_i_see_the_notification_form_heading
    expect(page).to have_text(I18n.t("devise.registrations.new.needs_email_decision.heading"))
  end

  def and_i_enter_a_valid_email_address
    fill_in I18n.t("devise.registrations.new.needs_password.fields.email.label"), with: "test_email@dev.gov.uk"
  end

  def and_i_enter_a_valid_password
    fill_in I18n.t("devise.registrations.new.needs_password.fields.password.label"), with: "testpass1"
  end

  def and_i_enter_an_identical_password_confirmation
    fill_in I18n.t("devise.registrations.new.needs_password.fields.password_confirm.label"), with: "testpass1"
  end

  def and_i_choose_yes
    choose I18n.t("devise.registrations.new.needs_email_decision.fields.email_signup.yes")
  end

  def and_i_click_continue
    click_button "Continue"
  end

  def then_i_see_confirm_email_page
    expect(page).to have_text("Confirm your email address")
  end

  def and_i_see_go_to_account_button
    expect(page).to have_link("Go to your GOV.UK account")
  end
end
