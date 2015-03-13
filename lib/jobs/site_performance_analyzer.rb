module Jobs
  class SitePerformanceAnalyzer
    class << self
      def queue
        :default
      end

      def perform(site_id)
        site = Site.find site_id
        site.global_performance_analysis!
      end
    end
  end
end
