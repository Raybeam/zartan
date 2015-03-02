module Jobs
  class ProvisionProxies
    class << self
      def perform(site_id, source_id, desired_proxy_count)
        source = Source.find source_id
        num_proxies = desired_proxy_count - source.proxies.length
        if num_proxies > 0
          proxies = source.provision_proxies num_proxies

          site = Site.find site_id
          site.add_proxies(proxies)
        end
      end
    end
  end
end
