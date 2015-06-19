module Jobs
  class ProvisionProxies
    class << self
      def perform(site_id, source_id, desired_proxy_count)
        source = Source.find source_id
        if desired_proxy_count > source.proxies.active.length
          site = site_id.nil? ? Site::NoSite : Site.find(site_id)
          proxies = source.provision_proxies desired_proxy_count, site
        end
      end
    end
  end
end
