class ProxiesController < ApplicationController
  def show
    @proxy = Proxy.find(params[:id])
  end
end
