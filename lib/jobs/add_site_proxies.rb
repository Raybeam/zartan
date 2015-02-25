module Jobs
  class AddSiteProxies
    class << self
      def perform(site_id)
        Site.find(site_id).add_proxies
      end
    end
  end
end
