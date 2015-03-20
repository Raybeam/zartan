class SessionsController < ApplicationController

  def create
    domain = env["omniauth.auth"]["info"]["email"].split('@').last
    allowed_domains = ['raybeam.com']
    if allowed_domains.include?(domain)
      user = User.from_omniauth(env["omniauth.auth"])
      session[:user_id] = user.id
      flash[:notice] = "Welcome #{user.name}, you have now been verified!"
      redirect_to sites_path
    else
      flash[:warning] = "You must be an employee to access Zartan."
      redirect_to root_path
    end
  end

  def destroy
    session[:user_id] = nil
    flash[:notice] = "Session terminated!"
    redirect_to root_path
  end

end