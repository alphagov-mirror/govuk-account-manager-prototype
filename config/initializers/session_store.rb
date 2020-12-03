GovukAccountManagerPrototype::Application.config.session_store :cookie_store,
                                                               key: "_govuk_account_manager_prototype_session",
                                                               same_site: :strict,
                                                               secure: Rails.env.production?
