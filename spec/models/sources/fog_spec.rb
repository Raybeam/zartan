RSpec.describe Sources::DigitalOcean, type: :model do
  let(:source) {create(:digital_ocean_source)}
  let(:proxy) {create(:proxy)}
  let(:site) {create(:site)}

  context '#provision_proxies' do
    it 'provisions multiple proxies, ignoring previously unknown servers' do
      expect(source).to receive(:validate_config!).and_return(true)
      expect(source).to receive(:provision_proxy).exactly(3).times
      expect(source).to receive(:find_orphaned_servers!).twice.and_return(2)
      expect(source).to receive(:num_servers_building).and_return(5)

      source.provision_proxies(10, double)
    end

    it 'does nothing if the config is invalid' do
      expect(source).to receive(:validate_config!).and_return(false)
      expect(source).to receive(:provision_proxy).never

      source.provision_proxies(3, double)
    end
  end

  context '#decommission_proxy' do
    it 'decommisions a proxy' do
      server = double(:destroy => double, :name => 'Phil')
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
      @server = double(:name => "Beatrice")
      connection = double(:servers => [@server])
      expect(source).to receive(:connection).and_return(connection)
    end

    it 'finds a server missing from the database' do
      allow(@server).to receive(:public_ip_address).and_return('N/A')
      expect(@server).to receive(:ready?).and_return(true)
      expect(source).to receive(:server_is_proxy_type?).and_return(true)
      expect(source).to receive(:save_server)

      expect(source.find_orphaned_servers!).to eq 1
    end

    it 'ignores a server already in the database' do
      expect(@server).to receive(:public_ip_address).and_return(proxy.host)
      expect(@server).to receive(:ready?).and_return(true)
      expect(source).to receive(:server_is_proxy_type?).and_return(true)
      expect(source).to receive(:save_server).never

      expect(source.find_orphaned_servers!).to eq 0
    end

    it 'ignores a server that does not run a proxy' do
      expect(@server).to receive(:public_ip_address).never
      expect(@server).to receive(:ready?).never
      expect(source).to receive(:server_is_proxy_type?).and_return(false)
      expect(source).to receive(:save_server).never

      expect(source.find_orphaned_servers!).to eq 0
    end

    it 'ignores a server that is not ready' do
      expect(@server).to receive(:public_ip_address).never
      expect(@server).to receive(:ready?).and_return(false)
      expect(source).to receive(:server_is_proxy_type?).and_return(true)
      expect(source).to receive(:save_server).never

      expect(source.find_orphaned_servers!).to eq 0
    end
  end

  context '#num_servers_building' do
    it 'counts the number of servers that are building' do
      ready_server = double('ready_server', :ready? => true)
      new_server = double('new_server', :ready? => false)
      other_server = double('other_server')
      connection = double('connection', :servers => [
        ready_server, new_server, other_server
      ])
      expect(source).to receive(:connection).and_return(connection)
      expect(source).to receive(:server_is_proxy_type?).with(ready_server).
        and_return(true)
      expect(source).to receive(:server_is_proxy_type?).with(new_server).
        and_return(true)
      expect(source).to receive(:server_is_proxy_type?).with(other_server).
        and_return(false)

      expect(source.send(:num_servers_building)).to eq 1
    end
  end

  context '#server_ready_timeout' do
    it 'uses the environment timeout' do
      redis = Zartan::Redis.connect
      redis.flushdb
      Zartan::Config.new['server_ready_timeout'] = 40

      expect(source.send(:server_ready_timeout)).to eq 40

      redis.flushdb
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
      expect(source).to receive(:server_ready_timeout)
      expect(source).to receive(:create_server).and_return(server)
      expect(source).to receive(:add_error)

      source.send(:provision_proxy, site)
    end

    it 'saves a properly created server' do
      server = double(:wait_for => double, :public_ip_address => 'N/A', :name => 'Tim')
      expect(source).to receive(:server_ready_timeout)
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
