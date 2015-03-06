class ConfigController < ApplicationController
  def show
    @config = Zartan::Config.new
  end
  
  def set
    config = Zartan::Config.new
    begin
      config[params.require(:key)] = params.require(:value)
    rescue
      # swallow any errors and redirect as normal
    end
    
    redirect_to config_path
  end
end
