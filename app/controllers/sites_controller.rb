class SitesController < ApplicationController
  before_filter :set_site, only: %i(show update)
  
  def index
    @sites = Site.all
  end
  
  def show
  end
  
  def update
    @site.update_attributes(params.require(:site).permit(:min_proxies, :max_proxies))
    redirect_to site_path(@site)
  end
  
  private
  def set_site
    @site = Site.find(params[:id])
  end
end
