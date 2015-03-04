RSpec.describe Sources::DigitalOcean, type: :model do
  let(:source) {create(:digital_ocean_source)}
  let(:site) {create(:site)}
  let(:proxy) {create(:proxy)}
  let(:proxy_performance) do
    ProxyPerformance.create(:proxy => proxy, :site => site)
  end

  context '#server_by_proxy' do
    it 'retrieves a server that matches the proxy' do
      server1 = double('server1', :public_ip_address => '172.0.0.1')
      server2 = double('server2', :public_ip_address => proxy.host)
      connection = double('connection', :servers => [server1, server2])
      expect(source).to receive(:connection).and_return(connection)

      expect(source.send(:server_by_proxy, proxy)).to be server2
    end
  end

  context 'mapping config names to config ids' do
    it 'uses the saved id if available' do
      source.config['image_id'] = 1
      expect(source).to receive(:names_to_ids).never

      expect(source.image_id).to eq 1
    end

    it 'translates name to id if the id is not saved' do
      expect(source).to receive(:names_to_ids) {source.config['image_id'] = 1}

      expect(source.image_id).to eq 1
    end

    it 'retrieves ids for all of the ID_TYPES' do
      expect(source).to receive(:retrieve_image_id).and_return(0)
      expect(source).to receive(:retrieve_flavor_id).and_return(1)
      expect(source).to receive(:retrieve_region_id).and_return(2)

      source.send(:names_to_ids)

      Sources::DigitalOcean::ID_TYPES.each_with_index do |id_type, i|
        expect(source.send(id_type)).to eq i
      end
    end

    it 'transforms image name to id' do
      image1 = double(:name => 'foo', :id => 1)
      image2 = double(:name => source.config['image_name'], :id => 2)
      connection = double(:images => [image1, image2])
      expect(source).to receive(:connection).and_return(connection)

      expect(source.send(:retrieve_image_id)).to eq 2
    end

    it 'transforms flavor name to id' do
      flavor1 = double(:name => 'foo', :id => 1)
      flavor2 = double(:name => source.config['flavor_name'], :id => 2)
      connection = double(:flavors => [flavor1, flavor2])
      expect(source).to receive(:connection).and_return(connection)

      expect(source.send(:retrieve_flavor_id)).to eq 2
    end

    it 'transforms region name to id' do
      region1 = double(:name => 'foo', :id => 1)
      region2 = double(:name => source.config['region_name'], :id => 2)
      connection = double(:regions => [region1, region2])
      expect(source).to receive(:connection).and_return(connection)

      expect(source.send(:retrieve_region_id)).to eq 2
    end
  end

end
