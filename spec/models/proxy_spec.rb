require 'rails_helper'

RSpec.describe Proxy, type: :model do

  let(:proxy) {create(:proxy)}
  let(:source) do
    blank_source = create(:digital_ocean_source)
    blank_source.proxies << proxy
    blank_source
  end
  let(:site) {create(:site)}
  let(:proxy_performance) do
    create(:proxy_performance, :site => site, :proxy => proxy)
  end

  context "SoftDeletable" do
    it 'is active by default' do
      expect(proxy.active?).to be_truthy
    end

    it 'is not active after being soft deleted' do
      proxy.soft_delete
      expect(proxy.active?).to be_falsey
    end

    it 'is in the list of active Proxies' do
      proxy.save
      expect(Proxy.active.length).to eq 1
    end

    it 'is not in the list of active Proxies when soft deleted' do
      proxy.soft_delete
      proxy.save
      expect(Proxy.active.length).to eq 0
    end
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

    it 'ignores soft deleted proxies' do
      proxy.soft_delete
      proxy.save
      proxies = Proxy.retrieve(
        :source => source,
        :site => site,
        :max_proxies => 5
      )
      expect(proxies).to eq []
    end

    it 'ignores proxies that have been removed from a site' do
      proxy_performance.soft_delete
      proxy_performance.save
      proxies = Proxy.retrieve(
        :source => source,
        :site => site,
        :max_proxies => 5
      )
      expect(proxies).to eq []
    end

    it 'ignores proxies that are already part of a site' do
      proxy_performance.save
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
      proxy.soft_delete
      proxy.save
      expect(Proxy).to receive(:find_or_initialize_by).and_return(proxy)

      Proxy.restore_or_initialize host: proxy.host, port: proxy.port

      expect(proxy.source).to be_nil
      expect(proxy.deleted_at).to be_nil
    end
  end

  context '#queue_decommission' do
    it 'does nothing if there remain sites using the proxy' do
      expect(proxy).to receive(:no_sites?).and_return(false)
      expect(Resque).to receive(:enqueue).never

      proxy.queue_decommission
    end

    it 'queues the decommission of an unused proxy' do
      expect(proxy).to receive(:no_sites?).and_return(true)
      expect(Resque).to receive(:enqueue_to)

      proxy.queue_decommission
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
      proxy_performance.soft_delete
      proxy_performance.save
      expect(proxy.no_sites?).to be_truthy
    end

    it 'returns false when sites are still using the proxy' do
      proxy_performance.save
      expect(proxy.no_sites?).to be_falsey
    end
  end
end
