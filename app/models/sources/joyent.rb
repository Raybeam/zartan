module Sources
  class Joyent < Sources::Fog
    class << self
      def required_fields
        super.merge({
          username: :string,
          password: :password,
          datacenter: :string,
          image_id: :string,
          package_id: :string
        })
      end
    end

    # Connect to Joyent to make sure our config is valid
    # You cannot verify custom images through Fog, but an incorrect image
    # UUID will cause an error when creating the server.
    def validate_config!
      if !config['image_id'].nil?
        connection.flavors.each do |f|
          if f.name == config['package_id']
            return true
          end
        end
      end
      return false
    end

    # Connnect to Joyent and find all of the proxies with the datacenter
    # provided with this source. Each proxy found will then be delete.
    # To selecte a different datacenter, a new source must be created or you
    # can edit the source with a new datacenter.
    # Pure virtual function intended for child classes to free all proxy resources
    def purge_servers(captcha=false)
      connection.servers.select do |s|
        puts("deleteing #{s.name} (id: #{s.id})")
        puts(connection.delete_machine(s.id))
      end
    end

    private

    # server_is_proxy_type?(server)
    # given a server, determine if it is running a proxy
    def server_is_proxy_type?(server)
      return server.image == config['image_id'] \
        && server.package == config['package_id']
    end

    def connection
      @connection ||= ::Fog::Compute.new(
        :provider => 'Joyent',
        :joyent_username => config['username'],
        :joyent_password => config['password'],
        :joyent_url => config['datacenter']
      )
    end

    def server_by_proxy(proxy)
      return NoServer unless validate_config!
      server = connection.servers.select do |s|
        s.primary_ip == proxy.host
      end.first

      server || NoServer
    end

    def create_server
      timestamp = Time.now.strftime("%Y.%m.%d-%H.%M.%S")
      server_output = connection.servers.create(
        name: "proxy-#{timestamp}-#{SecureRandom.uuid}",
        package: config['package_id'],
        image: config['image_id']
      )
    # Generally get this error when we've hit our limit on # of servers
    # but Joyent will produce errors here as well if form data is incorrect
    rescue => e
      puts(e)
      add_error(e.message)
      NoServer
    end
  end
end
