REDIS_CONFIG = YAML.load_file(Rails.root.join('config/redis.yml'))[Rails.env]

connection = Zartan::Redis.connect
Redis::Objects.redis = connection
Resque.redis = connection
