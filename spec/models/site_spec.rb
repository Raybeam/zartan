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
      
        expect(@redis.zscore( @site.proxy_pool.key, @proxy.id )).to be_nil
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
      
      
      it "should update the proxy's timestamp" do
        @site.enable_proxy @proxy
        
        @site.proxy_succeeded! @proxy
        
        expect(
          @redis.zscore( @site.proxy_pool.key, @proxy.id )
        ).to be_within(10).of(Time.now.to_i)
      end
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
      
      
      it "should update the proxy's timestamp" do
        @site.enable_proxy @proxy
        Zartan::Config.new['failure_threshold'] = 10
        
        @site.proxy_failed! @proxy
        
        expect(
          @redis.zscore( @site.proxy_pool.key, @proxy.id )
        ).to be_within(10).of(Time.now.to_i)
      end
    end
    
    
    describe "proxy selection" do
      it "should return NoProxy when there are none" do
        expect(@site.select_proxy).to eq(Proxy::NoProxy)
      end
      
      
      it "should return a Proxy when there are any" do
        @site.enable_proxy @proxy
        
        expect(@site.select_proxy).to be_instance_of(Proxy)
      end
      
      
      it "should return the least recently used proxy when there are several" do
        @proxy2 = create(:proxy, host: 'example.org')
        
        base_ts = Time.now.to_i
        @redis.zadd( @site.proxy_pool.key, base_ts, @proxy.id )
        @redis.zadd( @site.proxy_pool.key, (base_ts - 1), @proxy2.id )
        
        expect(@site.select_proxy).to eq(@proxy2)
      end
      
      
      it "should update the timestamp of the proxy it selects" do
        @site.enable_proxy @proxy
        
        @site.select_proxy
        
        expect(
          @redis.zscore( @site.proxy_pool.key, @proxy.id )
        ).to be_within(10).of(Time.now.to_i)
      end
      
      
      it "should return NoColdProxy when there are no sufficiently old proxies" do
        base_ts = Time.now.to_i - 60
        @redis.zadd( @site.proxy_pool.key, base_ts, @proxy.id )
        
        expect(@site.select_proxy(120)).to be_instance_of(Proxy::NoColdProxy)
      end
      
      
      it "should set the NoColdProxy's timeout appropriately" do
        base_ts = Time.now.to_i - 60
        @redis.zadd( @site.proxy_pool.key, base_ts, @proxy.id )
        
        expect(@site.select_proxy(120).timeout).to be_between(50,60).inclusive
      end
      
      
      it "should return a proxy object when there are sufficiently old proxies" do
        base_ts = Time.now.to_i - 60
        @redis.zadd( @site.proxy_pool.key, base_ts, @proxy.id )
        
        expect(@site.select_proxy(60)).to eq(@proxy)
      end
    end
  end
end
