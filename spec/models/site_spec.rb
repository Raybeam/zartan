require 'rails_helper'

RSpec.describe Site, type: :model do
  describe "redis interactions" do
    before :all do
      @redis = Zartan::Redis.connect
    end
    
    before :each do
      @site = create(:site)
      @proxy = create(:proxy)
      
      @redis.flushdb
    end
    
    after :all do
      @redis.flushdb
    end
    
    it "should add proxies to the proxy pool" do
      @site.enable_proxy @proxy
      
      expect(
        @redis.hget( @site.proxy_pool.key, @proxy.id )
      ).to eq(@proxy.to_json)
    end
    
    it "should record proxy successes" do
      value = 10
      @redis.zadd( @site.proxy_successes.key, value, @proxy.id )
      
      @site.proxy_succeeded! @proxy
      
      expect(
        @redis.zscore( @site.proxy_successes.key, @proxy.id )
      ).to eq(value + 1)
    end
    
    it "should record proxy failures" do
      value = 10
      @redis.zadd( @site.proxy_failures.key, value, @proxy.id )
      Zartan::Config.new['failure_threshold'] = 12
      
      @site.proxy_failed! @proxy
      
      expect(Site).not_to receive(:examine_health!)
      expect(
        @redis.zscore( @site.proxy_failures.key, @proxy.id )
      ).to eq(value + 1)
    end
    
    it "should notify the system when too many failures have occurred" do
      value = 10
      @redis.zadd( @site.proxy_failures.key, value, @proxy.id )
      Zartan::Config.new['failure_threshold'] = 11
      expect(Site).to receive(:examine_health!).with(@site.id, @proxy.id)
      
      @site.proxy_failed! @proxy
      
      expect(
        @redis.zscore( @site.proxy_failures.key, @proxy.id )
      ).to eq(value + 1)
    end
    
    it "should remove all traces of disabled proxies" do
      Zartan::Config.new['failure_threshold'] = 100
      @site.enable_proxy @proxy
      @site.proxy_succeeded! @proxy
      @site.proxy_failed! @proxy
      
      @site.disable_proxy @proxy
      
      expect(@redis.hexists( @site.proxy_pool.key, @proxy.id )).to be false
      expect(@redis.zscore( @site.proxy_successes.key, @proxy.id )).to be_nil
      expect(@redis.zscore( @site.proxy_failures.key, @proxy.id )).to be_nil
    end

    it "should generate a list of sites with their all-time success ratios" do
      ratios = @site.site_performance_ratios
      expect(ratios[0].success_ratio).to eq 0.25
      expect(ratios[1].success_ratio).to eq 0.5
    end
  end
end
