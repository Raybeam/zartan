# Runtime configuration management
#
# Construct a config object:
#     conf = Zartan::Config.new
# Set a value:
#     conf[:foo] = 'bar'
# Get a value (access is indifferent between strings/symbols):
#     conf['foo'] # => 'bar'
#     conf[:foo]  # => 'bar'
#
# A local cache is kept per instance, so you should create a new instance for
# each task you need to perform (i.e., don't keep a single instance around for
# a long time). If you want to explicitly clear the cache, you can call
# clear_cache. clear_cache returns self, so you can inline it:
#     conf.clear_cache[:foo]

module Zartan
  class Config
    def initialize
      @config_cache = {}
    end
  
    def [](name)
      name = name.to_sym
      @config_cache[name] ||= connection.get(key_for name)
      @config_cache[name]
    end
  
    def []=(name, new_value)
      name = name.to_sym
      connection.set(key_for(name), new_value)
      @config_cache[name] = new_value
      new_value
    end
  
    def clear_cache
      @config_cache = {}
      self
    end
  
    private
    def key_for name
      "config.#{name}"
    end
    
    def connection
      Zartan::Redis.connect
    end
  end
end