module AccountHelper
  def email_alert_frontend_base_uri
    Plek.new.website_root
  end

  def paths_without_feedback_footer
    [
      feedback_form_path,
      feedback_form_submitted_path,
    ]
  end

  def feedback_enabled_page
    account_disabled ? false : paths_without_feedback_footer.include?(request.env["PATH_INFO"])
  end

  def phase_banner_enabled
    account_disabled
  end

  def flash_as_notice(notice)
    [
      I18n.t("devise.registrations.update_needs_confirmation"),
    ].include? notice
  end

  def account_disabled
    ENV["FEATURE_FLAG_ACCOUNTS"] == "disabled"
  end
end
