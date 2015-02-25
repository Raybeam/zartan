class ProxyPerformance < ActiveRecord::Base
  belongs_to :proxy, inverse_of: :proxy_performances
  belongs_to :site, inverse_of: :proxy_performances

  include Concerns::SoftDeletable
end
