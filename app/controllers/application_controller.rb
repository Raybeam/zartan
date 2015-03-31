class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  delegate :allow?, to: :current_permission
  helper_method :allow?
  before_filter :authorize  

  private

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end
  helper_method :current_user

  def current_permission
    @current_permission ||= Permission.new(current_user)
  end

  def authorize
    if !current_permission.allow?(params[:controller], params[:action])
      flash[:error] = "You are not authorized! You must be signed in to access."
      redirect_to root_path
    end
  end 

end
