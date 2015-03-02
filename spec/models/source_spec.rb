require 'rails_helper'

RSpec.describe Source, type: :model do

  let(:source) {create(:blank_source)}
  let(:proxy) {create(:proxy)}
  let(:site) {create(:site)}

  context '#enqueue_provision' do
    it 'does nothing if no proxies were requested' do
      expect(
        source.enqueue_provision(site: site, num_proxies:0)
      ).to eq 0
    end

    it "does nothing if we're already at proxy capacity" do
      source.max_proxies = 1
      source.proxies << proxy
      source.save
      expect(
        source.enqueue_provision(site: site, num_proxies:1)
      ).to eq 0
    end

    context 'Resque job queued' do
      before(:each) do
        expect(Resque).to receive(:enqueue)
      end

      it 'queues more proxies to be created' do
        expect(
          source.enqueue_provision(site: site, num_proxies:1)
        ).to eq 1
      end

      it 'returns the number of proxies queued for creation' do
        source.proxies << proxy
        source.save
        expect(
          source.enqueue_provision(site: site, num_proxies:1)
        ).to eq 1
      end

      it 'caps the return value if we reach capacity' do
        source.max_proxies = 2
        source.proxies << proxy
        source.save
        expect(
          source.enqueue_provision(site: site, num_proxies:2)
        ).to eq 1
      end
    end
  end

  context '#desired_proxy_count' do
    it 'returns the maximum number of proxies if too many are requested' do
      expect(source.desired_proxy_count(1000000)).to eq source.max_proxies
    end

    it 'returns the number of proxies that would exist if more were created' do
      source.proxies.concat(proxy, create(:proxy, host: 'host2'))
      expect(source.desired_proxy_count(1)).to eq 3
    end
  end

  context '#add_proxy' do
    before(:each) do
      expect(Proxy).to receive(:restore_or_initialize).and_return(proxy)
    end

    it 'adds a proxy' do
      conflict = double(:conflict_exists? => false)
      expect(source).to receive(:fix_source_conflicts).and_return(conflict)

      source.send(:add_proxy, proxy.host, proxy.port)
      expect(proxy.source).to be source
    end

    it 'does nothing if the proxy is already in the database' do
      conflict = double(:conflict_exists? => true)
      expect(source).to receive(:fix_source_conflicts).and_return(conflict)

      source.send(:add_proxy, proxy.host, proxy.port)
      expect(proxy.source).to_not be source
    end
  end

  context '#fix_source_conflicts' do
    it 'does nothing if we are already the source' do
      proxy.source = source
      proxy.save

      expect(source.send(:fix_source_conflicts, proxy).conflict_exists?).to be_falsey
    end

    it 'transfers ownership of the proxy to self if old source is bad' do
      worse_source = create(:blank_source, :reliability => source.reliability-1)
      proxy.source = worse_source
      proxy.save

      expect(worse_source).to receive(:decommission_proxy)
      expect(source).to receive(:decommission_proxy).never
      expect(source.send(:fix_source_conflicts, proxy).conflict_exists?).to be_falsey
    end

    it 'keeps ownership of the proxy on other source if old source is good' do
      better_source = create(:blank_source, :reliability => source.reliability+1)
      proxy.source = better_source
      proxy.save

      expect(better_source).to receive(:decommission_proxy).never
      expect(source).to receive(:decommission_proxy)
      expect(source.send(:fix_source_conflicts, proxy).conflict_exists?).to be_truthy
    end
  end
end
