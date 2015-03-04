# Provides common methods for fog-based sources
module Sources
  class Fog < Source
    class << self
      # This should still be overwritten by child classes of Fog with
      # super.merge{...}
      def required_fields
        {proxy_port: :integer}
      end
    end

    # Spawn a thread for each proxy we need created
    def provision_proxies(num_proxies, site)
      threads = num_proxies.times.map do
        Thread.new {provision_proxy(site)}
      end
      threads.each {&:join}
    end

    # Destroy the server that the given proxy runs on
    def decommission_proxy(proxy)
      server = server_by_proxy proxy
      server.destroy
    end

    protected

    # Searches the service for the Fog server object that the proxy runs on
    def server_by_proxy(proxy)
      raise NotImplementedError, "Implement #{__callee__} in #{self.class.to_s}"
    end

    # Creates a Fog server.
    # This server object only needs to be initialized, not necessarily ready
    def create_server
      raise NotImplementedError, "Implement #{__callee__} in #{self.class.to_s}"
    end

    private

    def provision_proxy(site)
      server = create_server
      return unless server.wait_for { ready? }
      save_server server, site
    end

    # Wrapper for Source.add_proxy
    def save_server(server, site)
      add_proxy(server.public_ip_address, config['proxy_port'], site)
    end

  end
end
