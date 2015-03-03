RSpec.describe ProxyRequestor do
  let(:site) {create(:site)}
  let(:requestor) {ProxyRequestor.new site: site}
  let(:source) {create(:digital_ocean_source)}

  let(:perform1) {double(:success_ratio => 0.75)}
  let(:perform2) {double(:success_ratio => 0.5)}
  let(:perform3) {double(:success_ratio => 0.25)}
  let(:performances) {[perform1, perform2, perform3]}

  context '#run' do
    before :each do
      expect(requestor).to receive(:init_counters)
    end

    it 'requests proxies from each site' do
      requestor.instance_variable_set(:@proxies_needed, 5)
      expect(requestor).to receive(:performances).and_return([double,double])
      expect(requestor).to receive(:add_existing_proxies).twice
      expect(requestor).to receive(:provision_proxies).twice

      requestor.run
    end

    it "does nothing if we don't need any more proxies" do
      requestor.instance_variable_set(:@proxies_needed, 0)
      expect(requestor).to receive(:performances).never

      requestor.run
    end
  end

  context '#performances' do
    it 'produces a list of SitePerformance objects sorted by success_ratio' do
      3.times do
        create(:digital_ocean_source)
      end
      expect(SourcePerformance).to receive(:new).and_return(perform2)
      expect(SourcePerformance).to receive(:new).and_return(perform3)
      expect(SourcePerformance).to receive(:new).and_return(perform1)

      expect(requestor.send(:performances)).to eq [perform1, perform2, perform3]
    end

    it 'memoizes its return value' do
      requestor.instance_variable_set(:@performances, performances)
      expect(Source).to receive(:all).never

      expect(requestor.send(:performances)).to be performances
    end
  end

  context '#calculate_ratio_sum' do
    it 'calculates the sum of all the performance ratios' do
      expect(requestor).to receive(:performances).and_return(performances)
      expect(requestor.send(:calculate_ratio_sum)).to eq 1.5
    end
  end

  context '#add_existing_proxies' do
    before :each do
      requestor.instance_variable_set(:@proxies_needed, 100)
      requestor.instance_variable_set(:@ratio_sum, 1.0)
      allow(requestor).to receive(:site).and_return(site)
      expect(site).to receive(:add_proxies)
    end

    it 'does not need to partition more proxies' do
      perform = double(:success_ratio => 0.75, :source => source)
      proxies = double(:length => 75)
      expect(Proxy).to receive(:retrieve).with(
        source: source,
        site: site,
        max_proxies: 75
      ).and_return(proxies)

      expect(requestor.send(:add_existing_proxies, perform)).to eq 0
      expect(requestor.instance_variable_get(:@proxies_needed)).to eq 25
      expect(requestor.instance_variable_get(:@ratio_sum)).to eq 0.25
    end

    it 'needs to partition more proxies' do
      perform = double(:success_ratio => 0.75, :source => source)
      proxies = double(:length => 50)
      expect(Proxy).to receive(:retrieve).with(
        source: source,
        site: site,
        max_proxies: 75
      ).and_return(proxies)

      expect(requestor.send(:add_existing_proxies, perform)).to eq 25
      expect(requestor.instance_variable_get(:@proxies_needed)).to eq 50
      expect(requestor.instance_variable_get(:@ratio_sum)).to eq 0.25
    end
  end

  context '#provision_proxies' do
    it 'enqueues a provision step and updates statistics' do
      expect(perform1).to receive(:source).and_return(source)
      expect(source).to receive(:enqueue_provision).and_return(1)
      requestor.instance_variable_set(:@proxies_needed, 2)

      expect(requestor.send(:provision_proxies, perform1, 2)).to eq 1
    end
  end
end
