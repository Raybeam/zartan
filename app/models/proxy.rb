class Proxy < ActiveRecord::Base
  belongs_to :source
  has_many :proxy_performances, dependent: :delete_all
  has_many :sites, through: :proxy_performances
  
  NoProxy = Class.new
  NoColdProxy = Struct.new(:timeout)
end
