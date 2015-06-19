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
  
  def try_again(interval=nil)
    if interval.nil?
      config = Zartan::Config.new
      interval = config['server_ready_timeout'].to_i
    end
    
    { result: 'please_retry', interval: interval }
  end
end