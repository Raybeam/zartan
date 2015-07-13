module Zartan
  module SourceType
    extend self

    def all
      [
        ::Sources::DigitalOcean,
        ::Sources::Linode
      ]
    end
  end
end