REDIS_CONFIG = YAML.load_file(Rails.root.join('config/redis.yml'))[Rails.env]

Redis::Objects.redis = Zartan::Redis.connect