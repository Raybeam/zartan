class Proxy < ActiveRecord::Base
  belongs_to :source, inverse_of: :proxies
  has_many :proxy_performances, dependent: :destroy, inverse_of: :proxy
  has_many :sites, through: :proxy_performances

  def restore_or_initialize(host:, port:)
    proxy = self.find_or_initialize(host: host, port: port)
    proxy.source = nil unless proxy.deleted_at.nil?
    proxy.deleted_at = nil
    proxy
  end

  # Check to make sure the proxy is a candidate for being decomissioned.
  # If so, remove the proxy from the database and perform source-specific
  # work to tear down the proxy
  def decommission
    actually_decomission = false

    self.transaction isolation: :serializable do
      if self.sites.empty?
        # soft-delete the proxy so that nobody else tries to use it
        self.touch :deleted_at
        self.save
        # Decomission the proxy outside of the transaction
        actually_decomission = true
      end
    end
    # Tear down the proxy outside of the transaction because we don't need
    # the database anymore.
    self.source.decommission_proxy(self) if actually_decomission
  end
end
