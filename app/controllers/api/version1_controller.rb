module Api
  class Version1Controller < ActionController::Base
    def get_proxy
      render json: { result: 'success', payload: {} }
    end
    
    def report_result
      render :nothing
    end
  end
end