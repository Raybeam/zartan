module Zartan
  class Redis
    class << self
      def connect
        @connection ||= ::Redis.new(
          host: REDIS_CONFIG['host'],
          port: REDIS_CONFIG['port']
        )
      end
    end
  end
end