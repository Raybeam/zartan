module Api
  class Version2Controller < ActionController::Base

    def authenticate
      key = ApiKey.find_by_uuid(params[:api_key])

      if key.blank?
        render json: Responses::failure('Unrecognized API Key')
      else
        client = Client.create
        render json: Responses::success(client.to_h)
      end
    end
    
    def get_proxy
      check_client_id_and_site do
        older_than = (params[:older_than] || -1).to_i
        result = @client.select_proxy(@site, older_than)
        if result == Proxy::NoProxy
          render json: Responses::try_again
        elsif result.is_a? Proxy::NoColdProxy
          render json: Responses::try_again(result.timeout)
        else
          render json: Responses::success(result)
        end
      end
    end
    
    def report_result
      check_client_id_and_site do
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
      end
    end
    
    private
    def set_site
      @site = Site.find_or_create_by(name: params[:site_name])
    end

    def check_client_id_and_site(&block)
      @client = Client[params[:client_id]]
      if @client.valid?
        set_site
        yield
      else
        render json: Responses::Failure('Unrecognized client id')
      end
    end
  end
end
