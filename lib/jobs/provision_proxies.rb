module Jobs
  class ProvisionProxies
    class << self
      def perform(site_id, source_id, num_proxies)
        source = Source.find source_id
        proxies = source.provision_proxies num_proxies

        site = Site.find site_id
        site.proxies.concat(*proxies)
        site.save
      end
    end
  end
end
