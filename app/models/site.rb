class Site < ActiveRecord::Base
  has_many :proxy_performances, dependent: :delete_all
  has_many :proxies, through: :proxy_performances
end
