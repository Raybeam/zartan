module Sources
  class Static < Source
    def decommission_proxy(proxy)
      # Do nothing. The Proxy instance is already going to be deleted.
    end

    def provision_proxies(desired_proxy_count, site)
      # Do nothing. There's no automatic way to provision proxies from a static list.
    end

    def validate_config!
      true  # No config to validate
    end

    def max_proxies
      0  # Never try to provision extra proxies from a static list
    end

    # Expose the add_proxy method publicly
    def add_proxy(host, port, username = nil, password = nil, site = Site::NoSite)
      super
    end

    def load_from_file(path, site = Site::NoSite)
      open(path, 'r').each_line do |proxy_spec|
        proxy_spec.strip!
        next if proxy_spec.empty? or proxy_spec =~ /^#/

        host, port, username, password = nil, nil, nil, nil
        case proxy_spec
        when /^(.+):(.+)@([0-9.]+):([0-9]+)$/
          host = $3
          port = $4.to_i
          username = $1
          password = $2
        when /^([0-9.]+):([0-9]+)$/
          host = $1
          port = $2.to_i
        else
          add_error "Invalid proxy specification: #{proxy_spec}"
          next
        end

        unless self.proxies.active.where(host: host, port: port).count > 0
          add_proxy(host, port, username, password, site)
        end
      end
    end

    class << self
      def required_fields; {}; end
      def display_name; "Static List"; end
    end
  end
end
