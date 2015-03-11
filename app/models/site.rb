class Site < ActiveRecord::Base
  has_many :proxy_performances, dependent: :destroy, inverse_of: :site
  has_many :proxies, through: :proxy_performances

  # Redis-backed properties
  include Redis::Objects
  sorted_set :proxy_pool
  lock :proxy_pool, expiration: 60.seconds
  sorted_set :proxy_successes
  sorted_set :proxy_failures

  NoPerformanceReport = Class.new
  PerformanceReport = Struct.new(:times_succeeded, :times_failed) do
    def total
      @total ||= times_succeeded + times_failed
    end
  end

  # select_proxy()
  # select_proxy(older_than)
  # Find a suitable proxy for scraping this site.
  # Parameters:
  #   older_than: Don't return a proxy that was last used more recently than
  #               `older_than` seconds ago. The default is -1 (indicating that
  #               any proxy will do, as no proxy was used more than 1 second
  #               in the future)
  # Returns:
  #   - a Proxy instance if we found one used long enough ago
  #   - Proxy::NoColdProxy(timeout) if we found an instance, but it won't be
  #     old enough until `timeout` seconds from now
  #   - Proxy::NoProxy if we didn't find any proxies at all
  def select_proxy(older_than=-1)
    proxy_id, proxy_ts = nil, nil
    # Select the least recently used proxy, get its timestamp, then update its timestamp
    proxy_pool_lock.lock do
      proxy_info = proxy_pool.range(0, 0, with_scores: true)
      proxy_id, proxy_ts = proxy_info.first
      touch_proxy(proxy_id)
    end

    begin
      threshold_ts = (Time.now - older_than.seconds).to_i
      if proxy_ts.nil?
        # We didn't find a proxy
        Proxy::NoProxy
      elsif proxy_ts > threshold_ts
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
    proxy_pool_lock.lock do
      proxy_pool[proxy.id] = 0
    end
  end

  def disable_proxy(proxy)
    proxy_pool_lock.lock do
      proxy_pool.delete(proxy.id)
      proxy_successes.delete(proxy.id)
      proxy_failures.delete(proxy.id)
    end
    disable_proxy_in_database(proxy)
    proxy.queue_decommission
  end

  # The number of proxies currently used by the site
  def num_proxies
    proxy_pool.length
  end

  # The number of proxies needed to saturate the site's proxy pool
  def num_proxies_needed
    self.max_proxies - self.num_proxies
  end

  def active_performance?(proxy)
    !self.proxy_performances.active.where(proxy: proxy).empty?
  end

  def proxy_succeeded!(proxy)
    return unless active_performance? proxy
    proxy_pool_lock.lock do
      touch_proxy(proxy.id)
      proxy_successes.increment(proxy.id)
    end
  end

  def proxy_failed!(proxy)
    return unless active_performance? proxy
    conf = Zartan::Config.new
    failure_threshold = conf['failure_threshold'].to_i
    num_failures = 0
    proxy_pool_lock.lock do
      touch_proxy(proxy.id)
      num_failures = proxy_failures.increment(proxy.id)
    end
    if num_failures >= failure_threshold
      self.class.examine_health! self.id, proxy.id
    end
  end

  # Take one or more proxies and add them to the site in both postgres and redis
  def add_proxies(*new_proxies)
    self.transaction(Zartan::Application.config.default_transaction_options) do
      restore_or_create_performances(new_proxies)
      new_proxies.each {|p| self.enable_proxy p}
    end
  end

  # global_performance_analysis!()
  # Run a performance analysis on all proxies currently associated with the
  # site. Consistently successful proxies stay in service while unsuccessful
  # proxies get pruned.
  # Gets more proxies if there are too few proxies afterwards.
  # Parameters:
  #   None
  def global_performance_analysis!
    self.proxy_performances.active.each do |proxy_performance|
      disable_proxy_if_bad proxy_performance.proxy
    end
    request_more_proxies
  end

  # proxy_performance_analysis!()
  # Run a performance analysis on a single proxy associated with the site.
  # Consistently successful proxies stay in service while unsuccessful
  # proxies get pruned.
  # Starts new proxies if there are too few proxies.
  # Parameters:
  #   proxy: The prxoy whose performance is being analyzed
  def proxy_performance_analysis!(proxy)
    disable_proxy_if_bad proxy
    request_more_proxies
  end

  private

  def restore_or_create_performances(new_proxies)
    new_proxies.each do |proxy|
      ProxyPerformance.restore_or_create(proxy: proxy, site: self)
    end
  end

  # disable_proxy_if_bad(proxy)
  # Run a performance analysis on a single proxy associated with the site.
  # Consistently successful proxies stay in service while unsuccessful
  # proxies get pruned.
  # Parameters:
  #   proxy: The prxoy to get a report on
  def disable_proxy_if_bad(proxy)
    report = generate_proxy_report proxy
    if report.times_succeeded.to_f / report.total < success_ratio_threshold
      self.disable_proxy proxy
    end
  end

  # request_more_proxies()
  # Requests more proxies if the number of proxies currently in the site's
  # pool has gone below the minimum.
  # Parameters:
  #   None
  def request_more_proxies
    if self.num_proxies < self.min_proxies
      ProxyRequestor.new(site: self).run
    end
  end

  # success_ratio_threshold()
  # retrieves the configured succes ratio threshold
  # Parameters:
  #   None
  # Returns:
  #   - Float: the minimum allowed success ratio for proxies to be considered
  #     good
  def success_ratio_threshold
    return @success_ratio_threshold if @success_ratio_threshold
    conf = Zartan::Config.new
    @success_ratio_threshold = conf['success_ratio_threshold'].to_f
  end

  def touch_proxy(proxy_id)
    proxy_pool[proxy_id] = Time.now.to_i unless proxy_id.nil?
  end

  # disable_proxy_in_database(proxy)
  # dissassociates the proxy from the site in the database, but keeps the
  # ProxyPerformance object available for performance queries
  # Parameters:
  #   proxy - The proxy to dissassociate from the site
  # Returns:
  #   - Float: the minimum allowed success ratio for proxies to be considered
  #     good
  def disable_proxy_in_database(proxy)
    self.proxy_performances.where(proxy: proxy).first.soft_delete
  end

  # generate_proxy_report(proxy)
  # Generate a report of the current success/failure counts in redis for a
  # proxy, reset those redis counts, and update the long-term statistics
  # for that site/proxy relationship in postgres
  # Parameters:
  #   proxy: The prxoy to get a report on
  # Returns:
  #   - NoPerformanceReport if something goes wrong getting the proxy pool lock
  #   - Site::PerformanceReport if we retrieved the redis metrics
  def generate_proxy_report(proxy)
    report = NoPerformanceReport
    # Re-do the lock for every proxy to give other code a chance to
    # retrieve the lock
    proxy_pool_lock.lock do
      report = PerformanceReport.new(
        proxy_successes[proxy.id],
        proxy_failures[proxy.id]
      )
      proxy_successes[proxy.id] = 0
      proxy_failures[proxy.id] = 0
    end
    update_long_term_performance(proxy, report)
    report
  end

  # update_long_term_performance(proxy, report)
  # Wrapper method to ProxyPerformance.increment, removing dependence on
  # Site::PerformanceReport
  # Parameters:
  #   proxy: The prxoy that the report pertains to
  #   report: A Site::PerformanceReport object
  def update_long_term_performance(proxy, report)
    ProxyPerformance.find_or_create_by(:proxy => proxy, :site => self).increment(
      times_succeeded: report.times_succeeded,
      times_failed: report.times_failed
    )
  end

  class << self
    # examine_health!(site_id, proxy_id)
    # Queues a job to examine the health of a specific site/proxy relationship
    # Parameters:
    #   site_id - The id of the site to investigate
    #   proxy_id - The id of the proxy to investigate
    def examine_health!(site_id, proxy_id)
      Resque.enqueue(Jobs::TargetedPerformanceAnalyzer,
        site_id, proxy_id
      )
    end
  end
end
