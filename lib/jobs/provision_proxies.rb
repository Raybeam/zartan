module Jobs
  class ProvisionProxies
    class << self
      def perform(site_name, source_type, num_proxies)
        source = source_type.constantize.first
        proxies = source.provision_proxies num_proxies

        site = Site.find_by! name: site_name
        site << *proxies
        site.save
      end
    end
  end
end
