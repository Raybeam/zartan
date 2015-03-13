module Zartan
  module SourceType
    extend self
    
    def all
      [
        ::Sources::DigitalOcean
      ]
    end
  end
end