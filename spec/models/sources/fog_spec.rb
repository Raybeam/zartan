RSpec.describe Sources::DigitalOcean, type: :model do
  let(:source) {create(:digital_ocean_source)}
  let(:proxy) {create(:proxy)}
  let(:site) {create(:site)}

  context '#provision_proxies' do
    it 'provisions multiple proxies' do
      expect(source).to receive(:validate_config!).and_return(true)
      expect(source).to receive(:provision_proxy).exactly(3).times
      source.provision_proxies(3, double)
    end

    it 'does nothing if the config is invalid' do
      expect(source).to receive(:validate_config!).and_return(false)
      expect(source).to receive(:provision_proxy).never
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

  context '#find_orphaned_servers!' do
    before :each do
      @server = double
      connection = double(:servers => [@server])
      expect(source).to receive(:connection).and_return(connection)
    end

    it 'finds a server missing from the database' do
      expect(@server).to receive(:public_ip_address).and_return('N/A')
      expect(source).to receive(:server_is_proxy_type?).and_return(true)
      expect(source).to receive(:save_server)

      source.find_orphaned_servers!
    end

    it 'ignores a server already in the database' do
      expect(@server).to receive(:public_ip_address).and_return(proxy.host)
      expect(source).to receive(:server_is_proxy_type?).and_return(true)
      expect(source).to receive(:save_server).never

      source.find_orphaned_servers!
    end

    it 'ignores a server that does not run a proxy' do
      expect(@server).to receive(:public_ip_address).never
      expect(source).to receive(:server_is_proxy_type?).and_return(false)
      expect(source).to receive(:save_server).never

      source.find_orphaned_servers!
    end
  end

  context '#provision_proxy' do
    it 'silently ignores when the client class returns a NoServer object' do
      server = Sources::Fog::NoServer
      expect(source).to receive(:create_server).and_return(server)

      source.send(:provision_proxy, site)
    end

    it 'logs an error when the server times out' do
      server = double(:wait_for => false, :name => 'foo')
      expect(source).to receive(:create_server).and_return(server)
      expect(source).to receive(:add_error)

      source.send(:provision_proxy, site)
    end

    it 'saves a properly created server' do
      server = double(:wait_for => double)
      expect(source).to receive(:create_server).and_return(server)
      expect(source).to receive(:save_server)
      expect(source).to receive(:add_error).never

      source.send(:provision_proxy, site)
    end

    it 'catches errors' do
      expect(source).to receive(:create_server).and_raise(StandardError.new)
      expect(source).to receive(:add_error)

      source.send(:provision_proxy, site)
    end
  end
end
