class Client
  attr_accessor :id
  
  include ApiLogging

  include Redis::Objects
  EXPIRATION_INTERVAL = REDIS_CONFIG.fetch('client_session_timeout', 300)
  hash_key :next_proxy_id, expiration: EXPIRATION_INTERVAL
  hash_key :next_proxy_timestamp, expiration: EXPIRATION_INTERVAL

  def initialize(id)
    @id = id
  end

  def expiring_keys
    [next_proxy_id, next_proxy_timestamp]
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

  def reserve_proxy(site, proxy_id, proxy_ts)
    api_log(event: 'reserve', client_id: self.id, site: site.name, proxy_id: proxy_id, ready_unix_time: proxy_ts)
    next_proxy_id[site.id] = proxy_id
    next_proxy_timestamp[site.id] = proxy_ts
    touch
  end

  def get_proxy(site, older_than)
    api_log(event: 'request', client_id: self.id, site: site.name, older_than: older_than)
    proxy_ts = next_proxy_timestamp[site.id].andand.to_i
    if proxy_ts.nil?
      # We do not have a proxy reserved for this client/site combination.
      # Find a proxy using the Site methods.

      result = site.select_proxy(older_than)
      if result.is_a? Proxy::NotReady
        # Cache a hot proxy for a later request.
        reserve_proxy site, result.proxy_id, result.proxy_ts
      else
        api_log(event: 'found_proxy', client_id: self.id, site: site.name, proxy_id: result.id)
      end
    else
      threshold_ts = Time.now.to_i - older_than
      proxy_id = next_proxy_id[site.id]
      if proxy_ts > threshold_ts
        # Our chached proxy is still too hot
        api_log(event: 'reservation_not_ready', client_id: self.id, site: site.name)
        result = Proxy::NotReady.new(proxy_ts, threshold_ts, proxy_id)
      else
        # We have a chached proxy ready for use.
        api_log(event: 'reservation_ready', client_id: self.id, site: site.name, proxy_id: proxy_id)
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
