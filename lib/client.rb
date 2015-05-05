class Client  
  attr_accessor :id
  
  include Redis::Objects
  EXPIRATION_INTERVAL = REDIS_CONFIG.fetch('client_session_timeout', 300)
  hash_key :next_proxy, expiration: EXPIRATION_INTERVAL
  hash_key :next_proxy_available, expiration: EXPIRATION_INTERVAL
  
  def intialize(id)
    @id = id
  end
  
  def valid?
    [next_proxy, next_proxy_available].all?(&:exists?)
  end
  
  def touch
    [next_proxy, next_proxy_available].each { |k| k.expire(EXPIRATION_INTERVAL) }
  end
  
  def reserve_proxy(site, proxy, seconds_from_now)
    next_proxy[site.id] = proxy.id
    next_proxy_available[site.id] = (Time.now + seconds_from_now.seconds).to_i
    touch
  end
  
  def get_proxy(site)
    available_at = next_proxy_available[site.id]
    if available_at.nil?
      proxy = Proxy::NoProxy
    elsif Time.now.to_i < available_at
      proxy = Proxy::NoColdProxy(available_at - Time.now.to_i)
    else
      proxy = Proxy.find(next_proxy[site.id])
      [next_proxy, next_proxy_available].each { |k| k.delete(site.id) }
    end
    touch
    
    proxy
  end
  
  class << self
    alias_method :[], :new
    alias_method :find, :new
    
    def create
      new_client = new(UUIDTools::UUID.random_create.to_s)
      new_client.touch
      new_client
    end
  end
end
