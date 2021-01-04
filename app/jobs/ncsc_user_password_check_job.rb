class NcscUserPasswordCheckJob < ApplicationJob
  queue_as :ncsc_user_password_check

  def perform(user_id)
    user = User.find(user_id)

    has_banned_password = BannedPassword.pluck(:password).any? do |password|
      user.valid_password?(password)
    end

    user.update!(ncsc_password_match: has_banned_password)
  end
end
