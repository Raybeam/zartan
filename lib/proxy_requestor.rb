# Figuring out how many proxies to request from each source gets complicated.
# This class calculates statistics for each source and uses that to retrieve
# existing proxies out of the database for immediate consumption and enqueues
# provisioning jobs for later use.
class ProxyRequestor
  attr_reader :site

  def initialize(site:)
    @site = site
  end

  def run
    init_counters
    if @proxies_needed > 0
      performances.each do |perform|
        remaining_proxies_needed = add_existing_proxies(perform)
        provision_proxies(perform, remaining_proxies_needed)
      end
    end
  end

  private

  # Creates SourcePerformance objects for every Source in the database,
  # sorted by their success ratios decending.
  def performances
    unless @performances
      @performances = Source.all.map do |source|
        SourcePerformance.new(source: source, site: site)
      end
      @performances.sort! {|a,b| b.success_ratio <=> a.success_ratio}
    end
    @performances
  end

  # initialize @ratio_sum.  This is used to determine how many proxies
  # should be requested from each source.
  def calculate_ratio_sum
    @ratio_sum = performances.inject(0.0) {|sum,p| sum += p.success_ratio}
  end

  # Initialize @proxies_needed to how many total proxies the site needs
  def calculate_proxies_needed
    @proxies_needed = site.num_proxies_needed
  end

  # Initialize counters used to determine how many proxies to request
  # from each source
  def init_counters
    calculate_ratio_sum
    calculate_proxies_needed
  end

  def num_proxies_by_performance(perform)
    return @proxies_needed.to_f if @ratio_sum == 0
    (@proxies_needed * perform.success_ratio / @ratio_sum).round
  end

  # Takes existing proxies from the database and adds them to the site
  # Returns the number of proxies that we should ask the source to provision
  def add_existing_proxies(perform)
    num_proxies_to_request = num_proxies_by_performance perform
    proxies = Proxy.retrieve(
      source: perform.source,
      site: site,
      max_proxies: num_proxies_to_request
    )
    site.add_proxies(*proxies)
    @proxies_needed -= proxies.length
    @ratio_sum -= perform.success_ratio

    num_proxies_to_request - proxies.length
  end

  # Sends a request for more proxies to be provisioned.  Updates the running
  # count of the number of proxies needed based on the maximum number of
  # proxies the source is able to create
  def provision_proxies(perform, remaining_proxies_needed)
    num_proxies_to_build = perform.source.enqueue_provision(
      site: site,
      num_proxies: remaining_proxies_needed
    )
    @proxies_needed -= num_proxies_to_build
  end
end
