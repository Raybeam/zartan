module Zartan
  module SourceType
    extend self

    def all
      [
        ::Sources::DigitalOcean,
        ::Sources::Joyent
      ]
    end
  end
end
