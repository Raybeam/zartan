class ProxyPerformance < ActiveRecord::Base
  belongs_to :proxy
  belongs_to :site
end
