module Responses
  extend self
  
  def success(payload=nil)
    response = { result: 'success' }
    response[:payload] = payload unless payload.nil?
    response
  end
  
  def failure(message="An unknown error occurred")
    { result: 'error', reason: message }
  end
  
  def retry(interval=nil)
    if interval.nil?
      config = Zartan::Config.new
      interval = config['default_retry_interval'].to_i
    end
    
    { result: 'please_retry', interval: interval }
  end
end