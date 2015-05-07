class Proxy < ActiveRecord::Base
  belongs_to :source, inverse_of: :proxies
  has_many :proxy_performances, dependent: :destroy, inverse_of: :proxy
  has_many :sites, through: :proxy_performances

  include Concerns::SoftDeletable

  class << self
    # Retrieve active proxies from the database from a specific source that are
    # currently unaffiliated with a site
    def retrieve(source:, site:, max_proxies:)
      assosciated_proxy_ids = ProxyPerformance.where(site: site).map(&:proxy_id)
      self.active.where(source: source).reject { |p|
        assosciated_proxy_ids.include? p.id
      }.take(max_proxies)
    end

    def restore_or_initialize(host:, port:)
      proxy = self.find_or_initialize_by(host: host, port: port)
      proxy.source = nil
      proxy.deleted_at = nil
      proxy
    end
  end

  def queue_decommission
    if self.no_sites?
      Resque.enqueue_to(self.source.class.queue, Jobs::DecommissionProxy, self.id)
    end
  end

  # Check to make sure the proxy is a candidate for being decomissioned.
  # If any sites are still using the proxy then leave it be.
  # If no sites are still using the proxy, soft-delete the proxy and perform
  # source-specific work to tear down the proxy
  def decommission
    actually_decomission = false

    self.transaction(Zartan::Application.config.default_transaction_options) do
      if self.no_sites?
        # soft-delete the proxy so that nobody else tries to use it
        self.soft_delete
        self.save
        # Decomission the proxy outside of the transaction
        actually_decomission = true
      end
    end
    # Tear down the proxy outside of the transaction because we don't need
    # the database anymore.
    self.source.decommission_proxy(self) if actually_decomission
  end

  # Returns true if there are no sites actively connected to the proxy.
  def no_sites?
    self.proxy_performances.active.empty?
  end

  NoProxy = Class.new
  NoColdProxy = Struct.new(:proxy_ts, :threshold_ts, :proxy_id) do
    def timeout
      proxy_ts - threshold_ts
    end
  end
end
