class HomeController < ApplicationController
  def index
  	if current_user
      redirect_to sites_path
  	end
  end
end
