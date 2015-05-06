class Client
  attr_accessor :id

  include Redis::Objects
  EXPIRATION_INTERVAL = REDIS_CONFIG.fetch('client_session_timeout', 300)
  hash_key :next_proxy, expiration: EXPIRATION_INTERVAL
  hash_key :next_proxy_available, expiration: EXPIRATION_INTERVAL

  def initialize(id)
    @id = id
  end

  def expiring_keys
    [next_proxy, next_proxy_available]
  end

  def valid?
    expiring_keys.all?(&:exists?)
  end

  def touch
    expiring_keys.each do |k|
      k['keepalive'] = true
      k.expire(EXPIRATION_INTERVAL)
    end
  end

  def delete(site)
    expiring_keys.each { |k| k.delete(site.id) }
  end

  def reserve_proxy(site, proxy, seconds_from_now)
    next_proxy[site.id] = proxy.id
    next_proxy_available[site.id] = (Time.now + seconds_from_now.seconds).to_i
    touch
  end

  def get_proxy(site)
    available_at = next_proxy_available[site.id].andand.to_i
    if available_at.nil?
      proxy = Proxy::NoProxy
    elsif Time.now.to_i < available_at
      proxy = Proxy::NoColdProxy.new(available_at - Time.now.to_i)
    else
      proxy = Proxy.find(next_proxy[site.id])
      delete site
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
