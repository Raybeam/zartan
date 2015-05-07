module Api
  class Version2Controller < ActionController::Base
    around_action :check_api_key, only: :authenticate
    around_action :check_client_id, except: :authenticate
    before_action :set_site, only: [:get_proxy, :report_result]

    def authenticate
      client = Client.create
      render json: Responses::success(client.to_h)
    end
    
    def get_proxy
      older_than = (params[:older_than] || -1).to_i
      result = @client.get_proxy(@site, older_than)
      if result == Proxy::NoProxy
        render json: Responses::try_again
      elsif result.is_a? Proxy::NotReady
        render json: Responses::try_again(result.timeout)
      else
        render json: Responses::success(result)
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
      render json: Responses::success
    end
    
    private
    def set_site
      @site = Site.find_or_create_by(name: params[:site_name])
    end

    def check_client_id(&block)
      client_id = params[:client_id]
      if client_id.blank?
        render json: Responses::failure('Missing client id')
      else
        @client = Client[params[:client_id]]
        if @client.valid?
          yield
        else
          render json: Responses::failure('Unrecognized client id')
        end
      end
    end

    def check_api_key(&block)
      key = ApiKey.find_by_uuid(params[:api_key])

      if key.blank?
        render json: Responses::failure('Unrecognized API Key')
      else
        yield
      end
    end
  end
end
