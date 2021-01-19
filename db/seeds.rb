if Rails.env.development?
  Doorkeeper::AccessToken.destroy_all
  Doorkeeper::Application.destroy_all

  app = Doorkeeper::Application.create!(
    name: "GOV.UK Attribute Service",
    redirect_uri: "http://localhost",
    scopes: [:deanonymise_tokens],
  )

  token = Doorkeeper::AccessToken.create!(
    application_id: app.id,
    scopes: [:deanonymise_tokens],
  )

  token.token = "attribute-service-token"
  token.save!

  Doorkeeper::Application.create!(
    name: "Transition Checker",
    redirect_uri: "http://finder-frontend.dev.gov.uk/transition-check/login/callback",
    scopes: %i[email openid transition_checker],
    uid: "transition-checker-id",
    secret: "transition-checker-secret",
  )

  # Developement Credentials for GOV.UK Docker
  if ENV["FINDER_FRONTEND_OAUTH_CLIENT_ID"]
    ApplicationKey.create(
      application_uid: ENV.fetch("FINDER_FRONTEND_OAUTH_CLIENT_ID"),
      key_id: ENV.fetch("FINDER_FRONTEND_OAUTH_CLIENT_PUBLIC_KEY_UUID"),
      pem: ENV.fetch("FINDER_FRONTEND_OAUTH_CLIENT_PUBLIC_KEY"),
    )
  end
end
