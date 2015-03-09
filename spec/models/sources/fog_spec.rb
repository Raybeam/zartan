RSpec.describe Sources::DigitalOcean, type: :model do
  let(:source) {create(:digital_ocean_source)}
  let(:proxy) {create(:proxy)}
  let(:site) {create(:site)}

  context '#provision_proxies' do
    it 'provisions multiple proxies' do
      expect(source).to receive(:provision_proxy).exactly(3).times
      source.provision_proxies(3, double)
    end
  end

  context '#decommission_proxy' do
    it 'decommisions a proxy' do
      server = double(:destroy => double)
      expect(source).to receive(:server_by_proxy).and_return(server)

      source.decommission_proxy(proxy)
    end

    it 'silently ignores cases where the server could not be found' do
      expect(source).to receive(:server_by_proxy).and_return(
        Sources::Fog::NoServer
      )

      source.decommission_proxy(proxy)
    end
  end

  context '#provision_proxy' do
    it 'silently ignores when we do not have a valid config' do
      expect(source).to receive(:validate_config!).and_return(false)
      expect(source).to receive(:create_server).never

      source.send(:provision_proxy, site)
    end

    it 'logs an error when the server times out' do
      expect(source).to receive(:validate_config!).and_return(true)
      server = double(:wait_for => false, :name => 'foo')
      expect(source).to receive(:create_server).and_return(server)
      expect(source).to receive(:add_error)

      source.send(:provision_proxy, site)
    end

    it 'saves a properly created server' do
      expect(source).to receive(:validate_config!).and_return(true)
      server = double(:wait_for => double)
      expect(source).to receive(:create_server).and_return(server)
      expect(source).to receive(:save_server)
      expect(source).to receive(:add_error).never

      source.send(:provision_proxy, site)
    end

    it 'catches errors' do
      expect(source).to receive(:validate_config!).and_raise(StandardError.new)
      expect(source).to receive(:add_error)

      source.send(:provision_proxy, site)
    end
  end
end
