class Site < ActiveRecord::Base
  has_many :proxy_performances, dependent: :delete_all
  has_many :proxies, through: :proxy_performances
  
  # Redis-backed properties
  include Redis::Objects
  sorted_set :proxy_pool
  lock :proxy_pool, expiration: 60.seconds
  sorted_set :proxy_successes
  sorted_set :proxy_failures
  
  def select_proxy(older_than=-1)
    proxy_id, proxy_ts = nil, nil
    # Select the least recently used proxy, get its timestamp, then update its timestamp
    proxy_pool_lock.lock do
      proxy_info = proxy_pool.range(0, 0, with_scores: true)
      proxy_id, proxy_ts = proxy_info.first
      touch(proxy_id)
    end
    
    begin
      threshold_ts = (Time.now - older_than.seconds).to_i
      # TODO rethink this--probably shouldn't try to hit the database if proxy_ts is nil
      if proxy_ts and proxy_ts > threshold_ts
        # The proxy we found was too recently used.
        Proxy::NoColdProxy.new(proxy_ts - threshold_ts)
      else
        Proxy.find(proxy_id)
      end
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
    proxy_pool[proxy_id] = Time.now.to_i unless proxy_id.nil?
  end
  
  class << self
    def examine_health!(site_id, proxy_id)
      raise NotImplementedError
    end
  end
end
