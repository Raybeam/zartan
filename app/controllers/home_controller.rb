class HomeController < ApplicationController
  def index
    if current_user
      redirect_to activity_path
    end
  end
end
