RSpec.describe Activity, redis: true do  
  it 'should add new activities to redis' do
    Activity << 'hello'
    
    expect(@redis.lrange('activity', 0, 0).first).to match(/.*hello/)
  end
  
  it 'should prepend a timestamp to each event' do
    Activity << 'hello'
    
    expect(@redis.lrange('activity', 0, 0).first).to match(/^\[[0-9: -]+\]/)
  end
  
  it 'should maintain a maximum of max_activity_items events' do
    Zartan::Config.new['max_activity_items'] = 10
    20.times { |i| Activity << i.to_s }
    
    expect(@redis.llen('activity')).to eq(10)
  end
  
  it 'should iterate over the events in reverse order' do
    events = %w(one two three)
    events.each do |event|
      @redis.rpush 'activity', event
    end
    
    expect(Activity.each.to_a).to eq(events.reverse)
  end
end