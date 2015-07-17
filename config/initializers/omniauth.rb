OmniAuth.config.logger = Rails.logger

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
  GOOGLE_OMNIAUTH.fetch("google_client_id"),
  GOOGLE_OMNIAUTH.fetch("google_client_secret"),
  { scope: 'userinfo.email,userinfo.profile' }
end

