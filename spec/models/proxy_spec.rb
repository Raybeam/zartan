require 'rails_helper'

RSpec.describe Proxy, type: :model do
  
  let(:proxy) {create(:proxy)}
  let(:source) do
    blank_source = create(:blank_source)
    blank_source.proxies << proxy
    blank_source
  end
  let(:site) {create(:site)}
  let(:proxy_performance) do
    ProxyPerformance.create(:site => site, :proxy => proxy)
  end

  context '#retrieve' do
    before :each do
      site.save
      source.save
    end

    it 'finds all proxies unaffiliated with a site' do
      proxies = Proxy.retrieve(
        :source => source,
        :site => site,
        :max_proxies => 5
      )
      expect(proxies).to eq [proxy]
    end

    it 'ignores proxies that have been removed from a site' do
      proxy_performance = ProxyPerformance.create(
        :proxy => proxy,
        :site => site,
        :deleted_at => Time.now
      )
      proxies = Proxy.retrieve(
        :source => source,
        :site => site,
        :max_proxies => 5
      )
      expect(proxies).to eq []
    end

    it 'ignores proxies that are already part of a site' do
      proxy_performance = ProxyPerformance.create(
        :proxy => proxy,
        :site => site
      )
      proxies = Proxy.retrieve(
        :source => source,
        :site => site,
        :max_proxies => 5
      )
      expect(proxies).to eq []
    end

    it 'limits the number of proxies returned' do
      create(:proxy, :host => 'host2', :source => source).save
      proxies = Proxy.retrieve(
        :source => source,
        :site => site,
        :max_proxies => 1
      )
      expect(proxies.length).to eq 1
    end
  end

  context '#restore_or_initialize' do
    it '"initializes" a proxy' do
      expect(Proxy).to receive(:find_or_initialize_by).and_return(proxy)

      Proxy.restore_or_initialize host: proxy.host, port: proxy.port

      expect(proxy.source).to be_nil
      expect(proxy.deleted_at).to be_nil
    end

    it 'clears source and deleted_at for restored proxies' do
      proxy.touch :deleted_at
      proxy.save
      expect(Proxy).to receive(:find_or_initialize_by).and_return(proxy)

      Proxy.restore_or_initialize host: proxy.host, port: proxy.port

      expect(proxy.source).to be_nil
      expect(proxy.deleted_at).to be_nil
    end
  end

  context '#decommission' do
    before :each do
      expect(proxy).to receive(:transaction).and_yield
    end

    it 'does nothing if there still exist sites using the proxy' do
      expect(proxy).to receive(:no_sites?).and_return false
      expect(source).to receive(:decommission_proxy).never

      proxy.decommission
    end

    it 'soft-deletes the proxy, then decommissions it if no site is using it' do
      expect(proxy).to receive(:no_sites?).and_return true
      expect(source).to receive(:decommission_proxy)

      proxy.decommission

      expect(proxy.deleted_at).to_not be_nil
    end
  end

  context '#no_sites?' do
    it 'detects that there are no sites using the proxy' do
      proxy.save
      expect(proxy.no_sites?).to be_truthy
    end

    it 'knows there are no sites when proxy_performances are soft-deleted' do
      proxy_performance.touch :deleted_at
      proxy_performance.save
      expect(proxy.no_sites?).to be_truthy
    end

    it 'returns false when sites are still using the proxy' do
      proxy_performance.save
      expect(proxy.no_sites?).to be_falsey
    end
  end
end
