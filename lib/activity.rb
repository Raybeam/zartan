class Activity
  LOCK = Redis::Lock.new('activity_lock', expiration: 10.seconds, timeout: 12.seconds)
  
  def initialize
    @list = Redis::List.new('activity', maxlength: Zartan::Config.new['max_activity_items'])
  end
  
  def <<(event)
    Activity::LOCK.lock do
      now = Time.now.strftime '%F %T'
      @list << "[#{now}] #{event}"
    end
  end
  
  def each(&block)
    @list.values.reverse.each(&:block)
  end
  
  class << self
    def <<(event)
      new << event
    end
    
    def each(&block)
      new.each(&block)
    end
  end
end