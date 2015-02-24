REDIS_CONFIG = YAML.load_file(Rails.root.join('config/redis.yml'))[Rails.env]
