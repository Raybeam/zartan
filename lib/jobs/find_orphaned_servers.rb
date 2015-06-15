module Jobs
  class FindOrphanedServers
    class << self
      def perform(source_id, site_id, desired_proxy_count)
        source = Source.find(source_id)
        args = {desired_proxy_count: desired_proxy_count}
        args[:site] = Site.find(site_id) unless site_id.nil?
        source.find_orphaned_servers! **args
      end
    end
  end
end
