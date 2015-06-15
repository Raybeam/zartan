RSpec.describe Sources::DigitalOcean, type: :model do
  let(:source) {create(:digital_ocean_source)}
  let(:proxy) {create(:proxy)}
  let(:site) {create(:site)}

  context '#provision_proxies' do
    it 'provisions multiple proxies, ignoring previously unknown servers' do
      expect(source).to receive(:validate_config!).and_return(true)
      expect(source).to receive(:create_server).exactly(3).times
      expect(source).to receive(:find_orphaned_servers!)
      expect(source).to receive(:number_of_remote_servers).and_return(7)

      source.provision_proxies(10, double)
    end

    it 'does nothing if the config is invalid' do
      expect(source).to receive(:validate_config!).and_return(false)
      expect(source).to receive(:create_server).never

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
      expect(source).to receive(:schedule_orphan_search).never

      source.find_orphaned_servers! desired_proxy_count:1
    end

    it 'ignores a server already in the database' do
      expect(@server).to receive(:public_ip_address).and_return(proxy.host)
      expect(@server).to receive(:ready?).and_return(true)
      expect(source).to receive(:server_is_proxy_type?).and_return(true)
      expect(source).to receive(:save_server).never
      expect(source).to receive(:schedule_orphan_search)

      source.find_orphaned_servers! desired_proxy_count:1
    end

    it 'ignores a server that does not run a proxy' do
      expect(@server).to receive(:public_ip_address).never
      expect(@server).to receive(:ready?).never
      expect(source).to receive(:server_is_proxy_type?).and_return(false)
      expect(source).to receive(:save_server).never
      expect(source).to receive(:schedule_orphan_search)

      source.find_orphaned_servers! desired_proxy_count:1
    end

    it 'ignores a server that is not ready' do
      expect(@server).to receive(:public_ip_address).never
      expect(@server).to receive(:ready?).and_return(false)
      expect(source).to receive(:server_is_proxy_type?).and_return(true)
      expect(source).to receive(:save_server).never
      expect(source).to receive(:schedule_orphan_search)

      source.find_orphaned_servers! desired_proxy_count:1
    end

    it "does not save the server if it's pending decommission" do
      source.recent_decommissions << @server.name
      allow(@server).to receive(:public_ip_address).and_return('N/A')
      expect(@server).to receive(:ready?).and_return(true)
      expect(source).to receive(:server_is_proxy_type?).and_return(true)
      expect(source).to receive(:save_server).never
      expect(source).to receive(:schedule_orphan_search)

      source.find_orphaned_servers! desired_proxy_count:1
    end
  end

  context '#number_of_remote_servers' do
    it 'counts the number of servers on the remote end' do
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

      expect(source.send(:number_of_remote_servers)).to eq 2
    end
  end

  context '#pending_decommission', redis:true do
    it 'stores a finite number of server names pending deletion' do
      expect(source).to receive(:server_by_proxy).and_return(
        double(:name => "very_old_proxy")
      )
      source.pending_decommission double('very_old_proxy')
      # byebug
      expect(source.recent_decommissions.include? "very_old_proxy").
        to be_truthy
      Sources::Fog::FOG_RECENT_DECOMMISSIONS_LENGTH.times do |i|
        expect(source).to receive(:server_by_proxy).and_return(
          double(:name => "proxy-#{i}")
        )
        source.pending_decommission double("proxy-#{i}")
      end
      expect(source.recent_decommissions.include? "very_old_proxy").
        to be_falsey
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
end
