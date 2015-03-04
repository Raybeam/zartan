module Sources
  class DigitalOcean < Sources::Fog
    class << self
      def required_fields
        super.merge({
          client_id: :string,
          api_key: :password,
          image_name: :string,
          flavor_name: :string,
          region_name: :string
        })
      end
    end

    ID_TYPES = [:image_id, :flavor_id, :region_id]

    private

    def connection
      @connection ||= Fog::Compute.new(
        :provider => 'DigitalOcean',
        :digitalocean_api_key => config['api_key'],
        :digitalocean_client_id => config['client_id']
      )
    end

    def server_by_proxy(proxy)
      connection.servers.select{|s| s.public_ip_address == proxy.host}.first
    end

    # The ID_TYPES methods all are very similar, so dynamically create all
    # of them at once
    ID_TYPES.each do |id_type|
      class_eval <<-RUBY
        def #{id_type}
          key = '#{id_type}'
          return config[key] if config.has_key?(key)
          names_to_ids
          config[key]
        end
      RUBY
    end

    def names_to_ids
      config['image_id'] = retrieve_image_id
      config['flavor_id'] = retrieve_flavor_id
      config['region_id'] = retrieve_region_id
      self.save
    end

    # TODO: Some way to gracefully disable the source if the image_id can't
    # be found
    def retrieve_image_id
      name = config['image_name']
      id = connection.images.select do |i|
        i.name == name
      end.first.andand.id
      add_error "There is no source named #{name}" if id.nil?
      id
    end

    # TODO: Some way to gracefully disable the source if the flavor_id can't
    # be found
    def retrieve_flavor_id
      connection.flavors.select{|f| f.name == config['flavor_name']}.first.id
    end

    # TODO: Some way to gracefully disable the source if the region_id can't
    # be found
    def retrieve_region_id
      connection.regions.select{|r| r.name == config['region_name']}.first.id
    end

    def create_server
      connection.servers.create(
        name: "proxy-#{SecureRandom.uuid}",
        image_id: image_id,
        flavor_id: flavor_id,
        region_id: region_id
      )
    end

    Source.source_types << self
  end
end
