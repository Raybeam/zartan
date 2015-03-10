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

    BadConnection = Class.new
    class NoServer
      # destroy()
      # Silently ignore the destroy command for servers that can't be found
      # Error handling should happen in the child classes when searching for
      # the server
      def self.destroy
      end
    end

    # provision_proxies(num_proxies, site)
    # Spawn a thread for each proxy we need created
    # Parameters:
    #   num_proxies - How many proxies to create
    #   site - what site to add the proxies to after they're created
    def provision_proxies(num_proxies, site)
      threads = num_proxies.times.map do
        Thread.new {provision_proxy(site)}
      end
      threads.each(&:join)
    end

    # decommission_proxy()
    # Destroy the server that the given proxy runs on
    # Parameters:
    #   proxy - The proxy object that is to be decommissioned
    def decommission_proxy(proxy)
      server = server_by_proxy proxy
      server.destroy
    end

    # find_orphaned_servers!()
    # Searches through the list of servers to find any servers that have been
    # created, but fell through the cracks getting added to the database
    def find_orphaned_servers!
      connection.servers.each do |server|
        if server_is_proxy_type?(server) \
          && !Proxy.active.where(:host => server.public_ip_address).exists? \

          save_server server
        end
      end
    end

    protected

    # server_is_proxy_type?(server)
    # given a server, determine if it is running a proxy
    def server_is_proxy_type?(server)
      raise NotImplementedError, "Implement #{__callee__} in #{self.class.to_s}"
    end

    # server_by_proxy(proxy)
    # Searches the service for the Fog server object that the proxy runs on
    def server_by_proxy(proxy)
      raise NotImplementedError, "Implement #{__callee__} in #{self.class.to_s}"
    end

    # create_server()
    # Creates a Fog server.
    # This server object only needs to be initialized, not necessarily ready
    def create_server
      raise NotImplementedError, "Implement #{__callee__} in #{self.class.to_s}"
    end

    # connection()
    # Returns the connection object for the source
    def connection
      raise NotImplementedError, "Implement #{__callee__} in #{self.class.to_s}"
    end

    private

    # provision_proxy()
    # Provision a single proxy on the cloud and add it to site when ready
    def provision_proxy(site)
      # Return If we didn't get a server. The child class logs the error
      return unless validate_config!

      server = create_server

      return if server == NoServer
      if server.wait_for { ready? }
        save_server server, site
      else
        add_error("Timed out when creating #{server.name}")
      end
    rescue => e
      # Since this is within a thread we do not want one thread to kill
      # all the child threads.  Log the error in redis
      add_error "#{e.inspect}\n#{e.backtrace.join("\n")}"
    end

    # save_server()
    # Wrapper for Source.add_proxy
    def save_server(server, site = NoSite)
      add_proxy(server.public_ip_address, config['proxy_port'], site)
    end
  end
end
