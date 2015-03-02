require 'rails_helper'

RSpec.describe Site, type: :model do
  let(:site) {create(:site)}
  let(:proxy) {create(:proxy)}
  let(:proxy_performance) do
    ProxyPerformance.create(:proxy => proxy, :site => site)
  end

  describe "redis interactions" do
    before :all do
      @redis = Zartan::Redis.connect
    end

    before :each do
      @redis.flushdb
    end

    after :all do
      @redis.flushdb
    end


    describe "adding and removing proxies" do
      it "should add proxies to the proxy pool" do
        site.enable_proxy proxy

        expect(
          @redis.zscore( site.proxy_pool.key, proxy.id )
        ).to eq(0)
      end


      it "should remove all traces of disabled proxies" do
        Zartan::Config.new['failure_threshold'] = 100
        site.enable_proxy proxy
        site.proxy_succeeded! proxy
        site.proxy_failed! proxy
        expect(site).to receive(:disable_proxy_in_database)
        expect(proxy).to receive(:queue_decommission)

        site.disable_proxy proxy

        expect(@redis.zscore( site.proxy_pool.key, proxy.id )).to be_nil
        expect(@redis.zscore( site.proxy_successes.key, proxy.id )).to be_nil
        expect(@redis.zscore( site.proxy_failures.key, proxy.id )).to be_nil
      end
    end

    it "should calculate how many proxies need to be added" do
      old_proxies_needed = site.num_proxies_needed
      site.enable_proxy proxy

      expect(site.num_proxies_needed).to eq old_proxies_needed-1
    end


    describe "recording proxy success" do
      it "should record proxy successes" do
        value = 10
        @redis.zadd( site.proxy_successes.key, value, proxy.id )

        site.proxy_succeeded! proxy

        expect(
          @redis.zscore( site.proxy_successes.key, proxy.id )
        ).to eq(value + 1)
      end


      it "should update the proxy's timestamp" do
        site.enable_proxy proxy

        site.proxy_succeeded! proxy

        expect(
          @redis.zscore( site.proxy_pool.key, proxy.id )
        ).to be_within(10).of(Time.now.to_i)
      end
    end


    describe "recording proxy failure" do
      it "should record proxy failures" do
        value = 10
        @redis.zadd( site.proxy_failures.key, value, proxy.id )
        Zartan::Config.new['failure_threshold'] = 12

        site.proxy_failed! proxy

        expect(Site).not_to receive(:examine_health!)
        expect(
          @redis.zscore( site.proxy_failures.key, proxy.id )
        ).to eq(value + 1)
      end


      it "should notify the system when too many failures have occurred" do
        value = 10
        @redis.zadd( site.proxy_failures.key, value, proxy.id )
        Zartan::Config.new['failure_threshold'] = 11
        expect(Site).to receive(:examine_health!).with(site.id, proxy.id)

        site.proxy_failed! proxy

        expect(
          @redis.zscore( site.proxy_failures.key, proxy.id )
        ).to eq(value + 1)
      end


      it "should update the proxy's timestamp" do
        site.enable_proxy proxy
        Zartan::Config.new['failure_threshold'] = 10

        site.proxy_failed! proxy

        expect(
          @redis.zscore( site.proxy_pool.key, proxy.id )
        ).to be_within(10).of(Time.now.to_i)
      end
    end


    describe "proxy selection" do
      it "should return NoProxy when there are none" do
        expect(site.select_proxy).to eq(Proxy::NoProxy)
      end


      it "should return a Proxy when there are any" do
        site.enable_proxy proxy

        expect(site.select_proxy).to be_instance_of(Proxy)
      end


      it "should return the least recently used proxy when there are several" do
        proxy2 = create(:proxy, host: 'example.org')

        base_ts = Time.now.to_i
        @redis.zadd( site.proxy_pool.key, base_ts, proxy.id )
        @redis.zadd( site.proxy_pool.key, (base_ts - 1), proxy2.id )

        expect(site.select_proxy).to eq(proxy2)
      end


      it "should update the timestamp of the proxy it selects" do
        site.enable_proxy proxy

        site.select_proxy

        expect(
          @redis.zscore( site.proxy_pool.key, proxy.id )
        ).to be_within(10).of(Time.now.to_i)
      end


      it "should return NoColdProxy when there are no sufficiently old proxies" do
        base_ts = Time.now.to_i - 60
        @redis.zadd( site.proxy_pool.key, base_ts, proxy.id )

        expect(site.select_proxy(120)).to be_instance_of(Proxy::NoColdProxy)
      end


      it "should set the NoColdProxy's timeout appropriately" do
        base_ts = Time.now.to_i - 60
        @redis.zadd( site.proxy_pool.key, base_ts, proxy.id )

        expect(site.select_proxy(120).timeout).to be_between(50,60).inclusive
      end


      it "should return a proxy object when there are sufficiently old proxies" do
        base_ts = Time.now.to_i - 60
        @redis.zadd( site.proxy_pool.key, base_ts, proxy.id )

        expect(site.select_proxy(60)).to eq(proxy)
      end
    end

    it "should add proxies to both redis and postgres" do
      expect(site).to receive(:enable_proxy)

      site.add_proxies([proxy])

      expect(ProxyPerformance.where(:proxy => proxy, :site => site).exists?).
        to be_truthy
    end

    context '#generate_proxy_report' do
      it "resets successes and failures and returns their former values" do
        former_successes = 15
        @redis.zadd( site.proxy_successes.key, former_successes, proxy.id )
        former_failures = 10
        @redis.zadd( site.proxy_failures.key, former_failures, proxy.id )
        expect(site).to receive(:update_long_term_performance)

        report = site.send(:generate_proxy_report, proxy)

        expect(report.times_succeeded).to eq former_successes
        expect(report.times_failed).to eq former_failures
        expect(
          @redis.zscore( site.proxy_successes.key, proxy.id )
        ).to eq(0)
        expect(
          @redis.zscore( site.proxy_failures.key, proxy.id )
        ).to eq(0)
      end
    end
  end

  describe 'PerformanceReport' do
    it 'calculates the total number of successes + failures' do
      report = Site::PerformanceReport.new(1, 6)
      expect(report.total).to eq 7
    end
  end

  describe 'performance analysis' do
    it "should run a performance analysis on all proxies" do
      2.times.each do |i|
        proxy = create(:proxy, :port => i)
        proxy.sites << site
        proxy.save
      end
      expect(site).to receive(:proxy_performance_analysis!).twice

      site.global_performance_analysis!
    end

    it "should not disable a successful proxy" do
      report = Site::PerformanceReport.new(10, 1)
      expect(site).to receive(:generate_proxy_report).and_return(report)
      expect(site).to receive(:success_ratio_threshold).and_return(0.25)
      expect(site).to receive(:disable_proxy).never

      site.proxy_performance_analysis! proxy
    end

    it "should disable an unsuccessful proxy" do
      report = Site::PerformanceReport.new(10, 100)
      expect(site).to receive(:generate_proxy_report).and_return(report)
      expect(site).to receive(:success_ratio_threshold).and_return(0.25)
      expect(site).to receive(:disable_proxy)

      site.proxy_performance_analysis! proxy
    end
  end

  context '#success_ratio_threshold' do
    it 'retrieves the success ratio threshold config as a float' do
      conf = double('conf', :[] => "0.25")
      expect(Zartan::Config).to receive(:new).and_return(conf)
      expect(site.send(:success_ratio_threshold)).to eq 0.25
    end
  end

  context '#disable_proxy_in_database' do
    it 'soft deletes the site/proxy relationship' do
      proxy_performance.save

      site.send(:disable_proxy_in_database, proxy)

      proxy_performance.reload
      expect(proxy_performance.active?).to be_falsey
    end
  end

  context '#generate_proxy_report' do
    before :each do
      expect(site).to receive(:update_long_term_performance)
    end

    it 'returns NoPerformanceReport if the proxy lock fails' do
      expect(site.proxy_pool_lock).to receive(:lock)
      expect(Site::PerformanceReport).to receive(:new).never

      expect(site.send(:generate_proxy_report, proxy)).
        to be Site::NoPerformanceReport
    end

    it 'returns NoPerformanceReport if the proxy lock fails' do
      expect(site.proxy_pool_lock).to receive(:lock)
      expect(Site::PerformanceReport).to receive(:new).never

      expect(site.send(:generate_proxy_report, proxy)).
        to be Site::NoPerformanceReport
    end
  end

  context '#update_long_term_performance' do
    it 'updates long term performance of a site/proxy combination from redis' do
      proxy_performance.save
      expect(ProxyPerformance).to receive(:find).and_return(proxy_performance)
      times_succeeded = 20
      times_failed = 3
      report = Site::PerformanceReport.new(times_succeeded, times_failed)
      expect(proxy_performance).to receive(:increment).with(
        :times_succeeded => times_succeeded,
        :times_failed => times_failed
      )

      site.send(:update_long_term_performance, proxy, report)
    end
  end

  context '#examine_health!' do
    it 'enqueues a job to examine the site/proxy health' do
      expect(Resque).to receive(:enqueue)

      Site.examine_health! site.id, proxy.id
    end
  end
end
