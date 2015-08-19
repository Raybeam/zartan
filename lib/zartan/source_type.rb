module Zartan
  module SourceType
    extend self

    def all
      [
        ::Sources::DigitalOcean,
        ::Sources::Linode,
        ::Sources::Joyent,
        ::Sources::Static
      ]
    end
  end
end
