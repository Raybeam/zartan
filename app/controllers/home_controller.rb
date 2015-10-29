class HomeController < ApplicationController
  def index
    authentication_enabled = GOOGLE_OMNIAUTH.fetch("enabled", true)
    if current_user or !authentication_enabled
      # Go straight to /activity if we're either logged in or no auth is required
      redirect_to activity_path
    end
  end
end
