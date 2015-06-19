# Provides common methods for fog-based sources
module Sources
  class Fog < Source

    FOG_RECENT_DECOMMISSIONS_LENGTH = \
      REDIS_CONFIG.fetch('fog_recent_decommissions_length', 500)
    list :recent_decommissions, :maxlength => FOG_RECENT_DECOMMISSIONS_LENGTH

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

    # provision_proxies(desired_proxy_count, site)
    # Spawn a thread for each proxy we need created
    # Parameters:
    #   desired_proxy_count - Desired number of proxies owned by this source
    #     Could be less than self.max_proxies if underperforming compared to
    #     other sources
    #   site - what site to add the proxies to after they're created
    def provision_proxies(desired_proxy_count, site)
      # The config is invalid. The child class logs the error
      return unless validate_config!
      # Subtract the number of servers we have from the number of proxies we
      # want
      num_proxies = desired_proxy_count - number_of_remote_servers
      num_proxies.times do
        create_server
      end
      # Our recently created servers are probably not ready yet.
      # Check back later
      find_orphaned_servers!(
        site: site,
        desired_proxy_count: desired_proxy_count
      )
    end

    # decommission_proxy()
    # Destroy the server that the given proxy runs on
    # Parameters:
    #   proxy - The proxy object that is to be decommissioned
    def decommission_proxy(proxy)
      server = server_by_proxy proxy
      server.destroy
      Activity << "Decommissioned proxy #{proxy.host} (#{server.name})"
    end

    # find_orphaned_servers!(site)
    # Searches through the list of servers to find any servers that have been
    # created, but fell through the cracks getting added to the database
    # Adds them to the site if provided
    # Parameters:
    #   site - What site to add the found servers to (if any)
    #   desired_proxy_count - Until the site owns this many proxies, add new
    #     proxies to site
    def find_orphaned_servers!(site: Site::NoSite, desired_proxy_count: self.max_proxies)
      total_known_proxies = proxies.active.length
      servers_still_building = false
      connection.servers.each do |server|
        if server_is_proxy_type?(server)
          if !server.ready?
            servers_still_building = true
          elsif !Proxy.active.where(:host => server.public_ip_address).exists? \
            && !recent_decommissions.include?(server.name)

            # Don't add found proxies to the site if we've already reached our
            # quota
            total_known_proxies += 1
            site = Site::NoSite if total_known_proxies > desired_proxy_count

            save_server server, site

            msg = "Found orphaned proxy #{server.public_ip_address} (#{server.name})"
            msg += " for site #{site.name}" if site.respond_to? 'name'
            Activity << msg
          end
        end
      end
      if total_known_proxies < desired_proxy_count || servers_still_building
        schedule_orphan_search(site, desired_proxy_count)
      end
    end

    # number_of_remote_servers()
    # Searches through the list of servers to find the total number of servers
    # owned by this source
    def number_of_remote_servers
      connection.servers.inject(0) do |sum, s|
        sum += 1 if server_is_proxy_type?(s) 
        sum
      end
    end

    # The given proxy will be decommissioned by a future resque queue.
    # Mark the server's name in recent_decommissions so that it isn't marked
    # as an "orphaned" proxy
    def pending_decommission(proxy)
      server = server_by_proxy(proxy)
      recent_decommissions << server.name
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

    # validate_config!()
    # Connect to the cloud service to make sure our config is valid
    def validate_config!
      raise NotImplementedError, "Implement #{__callee__} in #{self.class.to_s}"
    end

    private

    def schedule_orphan_search(site, desired_proxy_count)
      site_id = site.respond_to?('id') ? site.id : nil
      Resque.enqueue_in_with_queue(
        self.class.queue,
        server_ready_timeout,
        Jobs::ProvisionProxies,
        site_id,
        self.id,
        desired_proxy_count
      )
    end

    # How long to wait for a server to be ready
    def server_ready_timeout
      Zartan::Config.new['server_ready_timeout'].to_i
    end

    # save_server()
    # Wrapper for Source.add_proxy
    # Parameters:
    #   site - What site to add the found servers to (if any)
    def save_server(server, *args)
      add_proxy(server.public_ip_address, config['proxy_port'], *args)
    end
  end
end
