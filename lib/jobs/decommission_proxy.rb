module Jobs
  class DecommissionProxy
    class << self
      def queue
        :default
      end

      def perform(proxy_id)
        proxy = Proxy.find proxy_id
        proxy.decommission
      end
    end
  end
end
