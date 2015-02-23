module Jobs
  class DecommissionProxy
    class << self
      def perform(proxy_id)
        proxy = Proxy.find id
        proxy.decommission
      end
    end
  end
end
