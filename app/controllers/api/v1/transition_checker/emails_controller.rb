class Api::V1::TransitionChecker::EmailsController < Doorkeeper::ApplicationController
  skip_before_action :verify_authenticity_token

  before_action -> { doorkeeper_authorize! :transition_checker }

  rescue_from ActionController::ParameterMissing do
    head :bad_request
  end

  def show
    user = User.find(doorkeeper_token.resource_owner_id)
    subscription = user.email_subscriptions.first

    head :not_found and return unless subscription
    head :no_content and return unless subscription.subscription_id

    begin
      state = Services.email_alert_api.get_subscription(subscription.subscription_id)
      has_ended = state.to_hash.dig("subscription", "ended_reason")
      head has_ended ? :gone : :no_content
    rescue GdsApi::HTTPGone, GdsApi::HTTPNotFound
      head :gone
    end
  end

  def update
    topic_slug = params.fetch(:topic_slug)

    EmailSubscription.transaction do
      user = User.find(doorkeeper_token.resource_owner_id)
      subscription = user.email_subscriptions.first
      break if subscription&.topic_slug == topic_slug

      if subscription
        subscription.update!(topic_slug: topic_slug)
      else
        subscription = EmailSubscription.create!(
          user_id: user.id,
          topic_slug: topic_slug,
        )
      end

      subscription.reactivate_if_confirmed
    end
  end
end
