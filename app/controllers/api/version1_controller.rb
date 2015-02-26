module Api
  class Version1Controller < ActionController::Base
    before_filter :set_site
    
    def get_proxy
      result = @site.select_proxy(params[:older_than])
      if result == Proxy::NoProxy
        render json: Response::try_again
      elsif result.is_a? Proxy::NoColdProxy
        render json: Response::try_again(result.timeout)
      else
        render json: Response::success(result)
      end
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