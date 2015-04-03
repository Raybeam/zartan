module Jobs
  class SitePerformanceAnalyzer
    class << self
      def queue
        :default
      end

      def perform(site_id)
        site = Site.find site_id
        site.request_more_proxies
      end
    end
  end
end
