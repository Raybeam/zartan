class SitePerformance
  attr_reader :source, :site

  def initialize(source:, site:)
    @source = source
    @site = site
  end

  def success_ratio
    performances = ProxyPerformance.joins(:proxy).
      where(
        :proxy_performances => {:site_id => site},
        :proxies => {:source_id => source}
      )
    times_succeeded = performances.map(&:times_succeeded).inject(:+)
    times_failed = performances.map(&:times_failed).inject(:+)
    total = times_succeeded + times_failed

    return 1 if total == 0
    times_succeeded/total
  end
end
