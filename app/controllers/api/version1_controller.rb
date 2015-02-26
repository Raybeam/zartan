module Api
  class Version1Controller < ActionController::Base
    before_filter :set_site
    
    def get_proxy
      render json: Response::success
    end
    
    def report_result
      begin
        @proxy = Proxy.find(params[:proxy_id])
        if params[:succeeded]
          @site.proxy_succeeded! @proxy
        else
          @site.proxy_failed! @proxy
        end
      rescue ActiveRecord::RecordNotFound => e
        # Swallow not-found-type errors
      end
      render json: Response::success
    end
    
    private
    def set_site
      @site = Site.find_or_create_by(name: params[:site_name])
    end
  end
end