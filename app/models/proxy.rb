class Proxy < ActiveRecord::Base
  belongs_to :source
  has_many :proxy_performances, dependent: :destroy, inverse_of: :proxy
  has_many :sites, through: :proxy_performances

  def restore_or_initialize(host:, port:)
    proxy = self.find_or_initialize(host: host, port: port)
    proxy.deleted_at = nil
    proxy
  end
end
