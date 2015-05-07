module Api
  class Version1Controller < ActionController::Base
    before_filter :set_site
    
    def get_proxy
      key = ApiKey.find_by_uuid(params[:api_key])

      unless key.blank?
        older_than = (params[:older_than] || -1).to_i
        result = @site.select_proxy(older_than)
        if result == Proxy::NoProxy
          render json: Responses::try_again
        elsif result.is_a? Proxy::NotReady
          render json: Responses::try_again(result.timeout)
        else
          render json: Responses::success(result)
        end
      else
        render json: Responses::failure('Unrecognized API Key')
      end
    end
    
    def report_result
      key = ApiKey.find_by_uuid(params[:api_key])
      unless key.blank?
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
        render json: Responses::success
      else
        render json: Responses::failure('Unrecognized API Key')
      end
    end
    
    private
    def set_site
      @site = Site.find_or_create_by(name: params[:site_name])
    end
  end
end