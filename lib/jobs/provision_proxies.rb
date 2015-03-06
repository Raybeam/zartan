module Jobs
  class ProvisionProxies
    class << self
      def queue
        :default
      end

      def perform(site_id, source_id, desired_proxy_count)
        source = Source.find source_id
        num_proxies = desired_proxy_count - source.proxies.active.length
        byebug
        if num_proxies > 0
          site = Site.find site_id
          proxies = source.provision_proxies num_proxies, site
        end
      end
    end
  end
end
