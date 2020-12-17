class DevisePasswordsController < Devise::PasswordsController
  # POST /resource/password
  def create
    super do |resource|
      next unless successfully_sent? resource

      record_security_event(SecurityActivity::PASSWORD_RESET_REQUEST, user: resource)
    end
  end

  # GET /resource/password/edit?reset_password_token=<token>
  def edit
    super

    reset_password_token = Devise.token_generator.digest(resource_class, :reset_password_token, params[:reset_password_token])
    resource_for_reset = resource_class.find_by(reset_password_token: reset_password_token)
    @reset_password_token_valid = resource_for_reset&.reset_password_period_valid?
  end

  # PUT /resource/password
  def update
    super do |resource|
      next unless resource.errors.empty?

      record_security_event(SecurityActivity::PASSWORD_RESET_SUCCESS, user: resource)
    end
  end

  def sent
    @email = params&.dig(:email)
  end

protected

  # The path used after sending reset password instructions
  def after_sending_reset_password_instructions_path_for(_resource_name)
    reset_password_sent_path(email: resource.email) if is_navigational_format?
  end
end
