class Site < ActiveRecord::Base
  has_many :proxy_performances, dependent: :delete_all
  has_many :proxies, through: :proxy_performances
  
  # Redis-backed properties
  include Redis::Objects
  sorted_set :proxy_pool
  sorted_set :proxy_successes
  sorted_set :proxy_failures
  
  def select_proxy(older_than=-1)
    proxy_id, proxy_ts = nil, nil
    redis.multi do
      # Select the least recently used proxy, get its timestamp, then update its timestamp
      proxy_id = proxy_pool[0]
      proxy_ts = proxy_pool.score(proxy_id)
      touch(proxy_id)
    end
    
    begin
      proxy = Proxy.find(proxy_id)
      threshold_ts = (Time.now - older_than.seconds).to_i
      if proxy_ts > threshold_ts
        # The proxy we found was too recently used.
        proxy = Proxy::NoColdProxy.new(proxy_ts - threshold_ts)
      end
      proxy
    rescue ActiveRecord::RecordNotFound => e
      Proxy::NoProxy
    end
  end
  
  def enable_proxy(proxy)
    proxy_pool[proxy.id] = 0
  end
  
  def disable_proxy(proxy)
    redis.multi do
      proxy_pool.delete(proxy.id)
      proxy_successes.delete(proxy.id)
      proxy_failures.delete(proxy.id)
    end
  end
  
  def proxy_succeeded!(proxy)
    touch(proxy.id)
    proxy_successes.increment(proxy.id)
  end
  
  def proxy_failed!(proxy)
    conf = Zartan::Config.new
    touch(proxy.id)
    num_failures = proxy_failures.increment(proxy.id)
    if num_failures >= conf['failure_threshold'].to_i
      self.class.examine_health! self.id, proxy.id
    end
  end
  
  private
  def touch(proxy_id)
    proxy_pool[proxy_id] = Time.now.to_i
  end
  
  class << self
    def examine_health!(site_id, proxy_id)
      raise NotImplementedError
    end
  end
end
