module Zartan
  module SourceType
    extend self

    def all
      [
        ::Sources::DigitalOcean,
        ::Sources::Linode,
        ::Sources::Joyent
      ]
    end
  end
end
