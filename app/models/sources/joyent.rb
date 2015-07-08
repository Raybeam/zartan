module Sources
  class Joyent < Sources::Fog
    '''
    #IDK WHATS NEEDED

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
    '''


    # Connect to Joyent to make sure our config is valid
    def validate_config!
      '''
      #DIGITAL OCEAN REFERENCE

      valid = false
      begin
        names_to_ids # Force re-evaluation of ids
        valid = (!image_id.nil? && !flavor_id.nil? && !region_id.nil?)
      rescue Excon::Errors::Unauthorized => e
        add_error "Invalid credentials"
      end
      valid
      '''
      true
    end

    def connection
      @connection ||= ::Fog::Compute.new(
        :provider => 'Joyent',
        :joyent_username => config['___'],
        :joyent_password => config['___']
      )
    end

    def server_by_proxy(proxy)
      return NoServer unless validate_config!
      server = connection.servers.select do |s|
        s.public_ip_address == proxy.host
      end.first

      server || NoServer
    end


    def create_server
      timestamp = Time.now.strftime("%Y.%m.%d-%H.%M.%S")
      connection.servers.create(
        name: "proxy-#{timestamp}-#{SecureRandom.uuid}",
        image: image_id,
        flavor: flavor_id,


        '''
        #possible properties
        "--image #{image}",
        "--flavor #{flavor}",
        "--distro #{distro}",
        "--networks #{networks}",
        "--environment #{environment}",
        "--node-name #{host_name}

        #DIGITAL OCEAN EXAMPLE

        name: "proxy-#{timestamp}-#{SecureRandom.uuid}",
        image_id: image_id,
        flavor_id: flavor_id,
        region_id: region_id
        '''
      )
    # Generally get this error when we've hit our limit on # of servers
    rescue Excon::Errors::Forbidden => e
      add_error(JSON.parse(e.response.body)['error_message'])
      NoServer
    end
  end
end
