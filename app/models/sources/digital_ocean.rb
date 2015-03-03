module Sources
  class DigitalOcean < Source
    class << self
      def required_fields
        {
          client_id: :string,
          api_key: :string,
          image_name: :string,
          flavor_name: :string
        }
      end
    end

    def decommission_proxy(proxy)

    end

    private

    def connection
      @connection ||= Fog::Compute.new(
        :provider => 'DigitalOcean',
        :digitalocean_api_key => config['api_key'],
        :digitalocean_client_id => config['client_id']
      )
    end

    def server_by_proxy(proxy)
      connection.servers.select{|s| s.public_ip_address == proxy.host}
    end

    def image_id
      connection.images.select{|i| i.name == config['image_name']}.first.id
    end

    def flavor_id
      connection.images.select{|f| f.name == config['flavor_name']}.first.id
    end

    def region_id
      regions = connection.images.select do |region|
        ["San Francisco 1", "New York 2", "New York 3"].include? region.name
      end
      # TODO: Randomly sample one from the list
      regions.first.id
    end

    def create
      server = connection.servers.create(
        name: "proxy-#{SecureRandom.uuid}",
        image_id: image_id,
        flavor_id: flavor_id,
        region_id: region_id
      )
    end

    Source.source_types << self
  end
end
