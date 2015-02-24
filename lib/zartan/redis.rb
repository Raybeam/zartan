module Zartan
  class Redis
    class << self
      def connect
        @connection ||= ::Redis.new(
          host: REDIS_CONFIG['host'],
          port: REDIS_CONFIG['port'],
          db: REDIS_CONFIG['db']
        )
      end
    end
  end
end