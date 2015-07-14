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
      if !config[:image_id].nil?
        for connection.flavors.each do |f|
          if f.name == config[:package_id]
            return true
          end
        end
      end
      return false
    end

    private

    # server_is_proxy_type?(server)
    # given a server, determine if it is running a proxy
    def server_is_proxy_type?(server)
      return server["image"] == config[:image_id] \
        && server["package"] == config[:package_id]
    end

    def connection
      @connection ||= ::Fog::Compute.new(
        :provider => 'Joyent',
        :joyent_username => config[:username],
        :joyent_password => config[:password],
        :joyent_url => config[:datacenter]
      )
    end

    def server_by_proxy(proxy)
      return NoServer unless validate_config!
      server = connection.list_machines.body.select do |s|
        s["primaryIp"] == proxy.host
      end.first

      server || NoServer
    end

    def create_server
      timestamp = Time.now.strftime("%Y.%m.%d-%H.%M.%S")
      server_output = connection.servers.create(
        name: "proxy-#{timestamp}-#{SecureRandom.uuid}",
        package: config[:package_id],
        image: config[:image_id]
      )
    # Generally get this error when we've hit our limit on # of servers
    # but Joyent will produce errors here as well if form data is incorrect
    rescue Excon::Errors::Forbidden => e
      add_error(JSON.parse(e.response.body)['error_message'])
      NoServer
    end
  end
end
