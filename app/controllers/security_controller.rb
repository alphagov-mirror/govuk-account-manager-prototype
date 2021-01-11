class SecurityController < ApplicationController
  before_action :authenticate_user!

  def show; end

  def report; end

  helper_method :activity
  def activity
    current_user
      .security_activities
      .show_on_security_page
      .order(created_at: :desc)
      .to_a
  end

  helper_method :data_exchanges
  def data_exchanges
    raw_exchanges = current_user
      .data_activities
      .where.not(oauth_application_id: AccountManagerApplication.application.id)
      .order(created_at: :desc)
      .to_a

    dedup_nearby(raw_exchanges)
      .compact
      .map { |a| activity_to_exchange(a) }
      .compact
  end

private

  def dedup_nearby(activities)
    last_activity = nil
    activities.map do |activity|
      if last_activity.nil? || !activity.very_similar_to(last_activity)
        last_activity = activity
        activity
      end
    end
  end

  def activity_to_exchange(activity)
    scopes = activity.scopes.split(" ").map(&:to_sym) - ScopeDefinition.new.hidden_scopes

    {
      application_name: activity.oauth_application.name,
      created_at: activity.created_at,
      scopes: scopes,
    }
  end
end
