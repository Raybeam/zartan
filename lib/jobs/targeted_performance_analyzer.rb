module Jobs
  class TargetedPerformanceAnalyzer
    class << self
      def perform(site_id, proxy_id)
        site = Site.find(site_id)
        proxy = Proxy.find(proxy_id)
        site.proxy_performance_analysis!(proxy)
      end
    end
  end
end
