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
    
    
    describe "adding and removing proxies" do
      it "should add proxies to the proxy pool" do
        @site.enable_proxy @proxy
      
        expect(
          @redis.zscore( @site.proxy_pool.key, @proxy.id )
        ).to eq(0)
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
    end
    
    
    describe "recording proxy success" do
      it "should record proxy successes" do
        value = 10
        @redis.zadd( @site.proxy_successes.key, value, @proxy.id )
      
        @site.proxy_succeeded! @proxy
      
        expect(
          @redis.zscore( @site.proxy_successes.key, @proxy.id )
        ).to eq(value + 1)
      end
      
      
      xit "should update the proxy's timestamp"
    end
    
    
    describe "recording proxy failure" do
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
      
      
      xit "should update the proxy's timestamp"
    end
    
    
    describe "proxy selection" do
      xit "should return NoProxy when there are none"
      xit "should return a Proxy when there are any"
      xit "should return the least recently used proxy when there are several"
      xit "should update the timestamp of the proxy it selects"
      xit "should return NoColdProxy when there are no sufficiently old proxies"
      xit "should set the NoColdProxy's timeout appropriately"
      xit "should return a proxy object when there are sufficiently old proxies"
    end
  end
end
