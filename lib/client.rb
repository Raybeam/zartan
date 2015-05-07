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

  def reserve_proxy(site, proxy_id)
    next_proxy[site.id] = proxy_id
    next_proxy_available[site.id] = Time.now.to_i
    touch
  end

  def get_proxy(site, older_than)
    reserved_at = next_proxy_available[site.id].andand.to_i
    # We do not have a proxy reserved for this client/site combination.
    # Find a proxy using the Site methods.
    if reserved_at.nil?
      result = site.select_proxy(older_than)
      # Cache a hot proxy for a later request.
      reserve_proxy site, result.proxy_id if result.is_a? Proxy::NoColdProxy
    else
      remaining_time = reserved_at + older_than - Time.now.to_i
      proxy_id = next_proxy[site.id]
      # Our chached proxy is still too hot
      if remaining_time > 0
        result = Proxy::NoColdProxy.new(remaining_time)
      # We have a chached proxy ready for use.
      else
        result = Proxy.find proxy_id
        delete site
      end
      site.touch_proxy proxy_id
    end
    touch

    result
  end

  def to_h
    {'client_id' => id}
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
