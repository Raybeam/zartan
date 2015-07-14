RSpec.describe Sources::Joyent, type: :model do
  let(:source) {create(:joyent_source)}
  let(:site) {create(:site)}
  let(:proxy) {create(:proxy)}
  let(:proxy_performance) do
    create(:proxy_performance, :proxy => proxy, :site => site)
  end

  context '#validate_config!' do
    it 'identifies a valid config' do
      expect(source.config).to have_key('image_id')
      expect(source.config).to have_key('package_id')
      expect(source.config['image_id']).to be
      expect(source.config['package_id']).to be

      expect(source.validate_config!).to be_truthy
    end

    it 'identifies an invalid config when an id is nil' do
      expect(source.config).to have_key('image_id')
      expect(source.config).to have_key('package_id')
      source.config['package_id'] = nil
      expect(source.config['image_id']).to be
      expect(source.config['package_id']).to be_nil

      expect(source.validate_config!).to be_falsey
    end
  end

  context '#server_is_proxy_type?' do
    it 'identifies a server that runs a proxy' do
      server = double(
        image_id: source.config['image_id'],
        package_id: source.config['package_id'],
      )
      puts(source.methods)
      expect(source.send(:server_is_proxy_type?, server)).to be_truthy
    end

    it 'identifies a server that has a different package' do
      server = double(
        image_id: source.config['image_id'],
        package_id: nil
      )
      expect(source.send(:server_is_proxy_type?, server)).to be_falsey
    end

    it 'identifies a server that has a different image' do
      server = double(
        image_id: nil,
        package_id: source.config['package_id']
      )
      expect(source.send(:server_is_proxy_type?, server)).to be_falsey
    end
  end

  context '#server_by_proxy' do
    it 'retrieves a server that matches the proxy' do
      expect(source).to receive(:validate_config!).and_return(true)
      server1 = double('server1', :public_ip_address => '172.0.0.1')
      server2 = double('server2', :public_ip_address => proxy.host)
      connection = double('connection', :servers => [server1, server2])
      expect(source).to receive(:connection).and_return(connection)

      expect(source.send(:server_by_proxy, proxy)).to be server2
    end

    it 'returns NoServer if we do not have a valid config' do
      expect(source).to receive(:validate_config!).and_return(false)

      expect(source.send(:server_by_proxy, proxy)).to be Sources::Fog::NoServer
    end

    it 'returns NoServer if we could not find the server' do
      expect(source).to receive(:validate_config!).and_return(true)
      server1 = double('server1', :public_ip_address => '172.0.0.1')
      server2 = double('server2', :public_ip_address => '10.0.0.0')
      connection = double('connection', :servers => [server1, server2])

      expect(source.send(:server_by_proxy, proxy)).to be Sources::Fog::NoServer
    end
  end

  context '#create_server' do
    it 'creates a server' do
      server = double('server')
      connection = double(:servers => double(:create => server))
      expect(source).to receive(:connection).and_return(connection)
      expect(source).to receive(:image_id).and_return(1)
      expect(source).to receive(:package_id).and_return(2)

      expect(source.send(:create_server)).to be server
    end

    it 'recovers when we have reached our droplet limit' do
      response = double(:body => ({'error_message' => "droplet limit"}.to_json))
      expect(source).to receive(:connection).and_raise(
        Excon::Errors::Forbidden.new("Error", nil, response)
      )
      expect(source).to receive(:add_error).with("droplet limit")

      expect(source.send(:create_server)).to be Sources::Fog::NoServer
    end
  end

end
