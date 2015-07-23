RSpec.describe Sources::Linode, type: :model do
  let(:source) {create(:linode_source)}
  let(:site) {create(:site)}
  let(:proxy) {create(:proxy)}
  let(:proxy_performance) do
    create(:proxy_performance, :proxy => proxy, :site => site)
  end

  context '#validate_config!' do
    it 'identifies a valid config' do
      expect(source).to receive(:names_to_ids)
      expect(source).to receive(:image_id).and_return 4
      expect(source).to receive(:flavor_id).and_return 5
      expect(source).to receive(:kernel_id).and_return 6
      expect(source).to receive(:data_center_id).and_return 7

      expect(source.validate_config!).to be_truthy
    end

    it 'identifies an invalid config when an id is nil' do
      expect(source).to receive(:names_to_ids)
      expect(source).to receive(:image_id).and_return 4
      expect(source).to receive(:flavor_id).and_return 5
      expect(source).to receive(:kernel_id).and_return 6
      expect(source).to receive(:data_center_id).and_return nil

      expect(source.validate_config!).to be_falsey
    end

    it 'identifies an invalid config when we fail to connect' do
      expect(source).to receive(:names_to_ids).
        and_raise(Excon::Errors::Unauthorized.new('test_error'))

      expect(source.validate_config!).to be_falsey
    end
  end

  context '#server_is_proxy_type?' do
    it 'identifies a server that runs a proxy' do
      server = double(
        name: '7-5-6-4-1234567890'
      )

      expect(source.send(:server_is_proxy_type?, server)).to be_truthy
    end

    it 'identifies a server that is not configured as expected' do
      server = double(
        name: '12-5-6-4-1234567890'
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

  context 'mapping config names to config ids' do
    it 'uses the saved id if available' do
      source.config['image_id'] = 4
      expect(source).to receive(:names_to_ids).never

      expect(source.image_id).to eq 4
    end

    it 'translates name to id if the id is not saved' do
      source.config.delete 'image_id'
      expect(source).to receive(:names_to_ids) {source.config['image_id'] = 4}

      expect(source.image_id).to eq 4
    end

    it 'retrieves ids for all of the ID_TYPES' do
      expect(source).to receive(:retrieve_image_id).and_return(4)
      expect(source).to receive(:retrieve_flavor_id).and_return(5)
      expect(source).to receive(:retrieve_kernel_id).and_return(6)
      expect(source).to receive(:retrieve_data_center_id).and_return(7)

      source.send(:names_to_ids)

      Sources::Linode::ID_TYPES.each_with_index do |id_type, i|
        expect(source.send("#{id_type}_id".to_sym)).to eq (i+4)
      end
    end

    it 'logs an error if the image id could not be retrieved' do
      image1 = {"LABEL" => "foo", "IMAGEID" => 1}
      image2 = {"LABEL" => "bar", "IMAGEID" => 2}
      connection = double(:image_list => double(:body => {"DATA" => [image1, image2]}))
      expect(source).to receive(:connection).twice.and_return(connection)
      expect(source).to receive(:add_error).with(
        "There is no image named #{source.config['image_name']}. Options are: foo, bar"
      )

      expect(source.send(:retrieve_image_id)).to be nil
    end

    it 'transforms image name to id' do
      image1 = {"LABEL" => "foo", "IMAGEID" => 1}
      image2 = {"LABEL" => source.config['image_name'], "IMAGEID" => 4}
      connection = double(:image_list => double(:body => {"DATA" => [image1, image2]}))
      expect(source).to receive(:connection).and_return(connection)

      expect(source.send(:retrieve_image_id)).to eq 4
    end

    it 'transforms flavor name to id' do
      flavor1 = double(:name => 'foo', :id => 1)
      flavor2 = double(:name => source.config['flavor_name'], :id => 5)
      connection = double(:flavors => [flavor1, flavor2])
      expect(source).to receive(:connection).and_return(connection)

      expect(source.send(:retrieve_flavor_id)).to eq 5
    end

    it 'transforms kernel name to id' do
      flavor1 = double(:name => 'foo', :id => 1)
      flavor2 = double(:name => source.config['kernel_name'], :id => 6)
      connection = double(:kernels => [flavor1, flavor2])
      expect(source).to receive(:connection).and_return(connection)

      expect(source.send(:retrieve_kernel_id)).to eq 6
    end

    it 'transforms data center name to id' do
      data_center1 = double(:location => 'foo', :id => 1)
      data_center2 = double(:location => source.config['data_center_name'], :id => 7)
      connection = double(:data_centers => [data_center1, data_center2])
      expect(source).to receive(:connection).and_return(connection)

      expect(source.send(:retrieve_data_center_id)).to eq 7
    end
  end

  context '#create_server' do
#    it 'creates a server' do
#      server = double('server')
#      connection = double(:servers => double(:create => server))
#      expect(source).to receive(:connection).and_return(connection)
#      expect(source).to receive(:image_id).and_return(1)
#      expect(source).to receive(:flavor_id).and_return(2)
#      expect(source).to receive(:region_id).and_return(3)

#      expect(source.send(:create_server)).to be server
#    end

#    it 'recovers when we have reached our droplet limit' do
#      response = double(:body => ({'error_message' => "droplet limit"}.to_json))
#      expect(source).to receive(:connection).and_raise(
#        Excon::Errors::Forbidden.new("Error", nil, response)
#      )
#      expect(source).to receive(:add_error).with("droplet limit")
#
#      expect(source.send(:create_server)).to be Sources::Fog::NoServer
#    end
  end

end
