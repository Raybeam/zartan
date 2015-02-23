class Source < ActiveRecord::Base
  has_many :proxies, dependent: :destroy, inverse_of: :source
end
