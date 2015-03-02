module Jobs
  class AddSiteProxies
    class << self
      def perform(site_id)
        site = Site.find(site_id)
        ProxyRequestor.new(site).run
      end
    end
  end
end
