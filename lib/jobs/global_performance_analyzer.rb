module Jobs
  class GlobalPerformanceAnalyzer
    class << self
      def queue
        :default
      end

      def perform
        Site.all.each do |site|
          site.global_performance_analysis!
        end
      end
    end
  end
end
