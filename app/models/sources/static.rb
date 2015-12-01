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

    class << self
      def required_fields; {}; end
      def display_name; "Static List"; end
    end
  end
end
