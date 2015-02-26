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
    times_succeeded = performances.pluck(:times_succeeded).inject(0, :+)
    times_failed = performances.pluck(:times_failed).inject(0, :+)
    total = times_succeeded + times_failed

    return 1.0 if total == 0
    times_succeeded.to_f/total
  end
end
