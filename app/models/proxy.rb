class Proxy < ActiveRecord::Base
  belongs_to :source
  has_many :proxy_performances, dependent: :destroy, inverse_of: :proxy
  has_many :sites, through: :proxy_performances
  acts_as_paranoid
end
