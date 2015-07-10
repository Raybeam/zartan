module Sources
  class Joyent < Sources::Fog
    class << self
      def required_fields
        super.merge({
          username: :string,
          password: :password,
          image_name: :string,
          package_name: :string
        })
      end
    end

    ID_TYPES = ['image', 'package']

    # Connect to Joyent to make sure our config is valid
    def validate_config!
      valid = false
      begin
        names_to_ids # Force re-evaluation of ids
        valid = (!image_id.nil? && !package_id.nil?)
      rescue Excon::Errors::Unauthorized => e
        add_error "Invalid credentials"
      end
      valid
    end

    private

    # server_is_proxy_type?(server)
    # given a server, determine if it is running a proxy
    def server_is_proxy_type?(server)
      return server.image_id == self.image_id \
        && server.package_id == self.package_id
    end

    def connection
      @connection ||= ::Fog::Compute.new(
        :provider => 'Joyent',
        :joyent_username => config['username'],
        :joyent_password => config['password']
      )
    end

    def server_by_proxy(proxy)
      return NoServer unless validate_config!
      server = connection.servers.select do |s|
        s.public_ip_address == proxy.host
      end.first

      server || NoServer
    end

    # The ID_TYPES methods all are very similar, so dynamically create all
    # of them at once
    ID_TYPES.each do |id_type|
      class_eval <<-RUBY
        # image_id()
        # package_id()
        # Get the image/package id.
        # If the id is undefined, translate image/package name to id by
        # connecting to Joyent.
        # Returns cached value if already calculated
        # Parameters:
        #   None
        # Returns:
        #   - a numeric id representing the image/package on Joyent
        #   - nil if not found
        def #{id_type}_id
          key = '#{id_type}_id'
          return config[key] if config.has_key?(key)
          names_to_ids
          config[key]
        end

        # retrieve_image_id()
        # retrieve_package_id()
        # Retrieve image/package id from Joyent
        # If the id is not found then adds to the source's persistent error log
        # Parameters:
        #   None
        # Returns:
        #   - a numeric id representing the image/package on Joyent
        #   - nil if not found
        def retrieve_#{id_type}_id
          name = config['#{id_type}_name']
          id = connection.#{id_type.pluralize}.select do |i|
            i.name == name
          end.first.andand.id
          if id.nil?
            names = connection.#{id_type.pluralize}.map(&:name).join(", ")
            add_error "There is no #{id_type} named \#{name}. " \
              "Options are: \#{names}"
          end
          id
        end
      RUBY
    end

    # names_to_ids()
    # Retrieve all ids from the server and save them in the database
    # Does not save to the database if at least one id is nil.
    # Parameters:
    #   None
    def names_to_ids
      config['image_id'] = retrieve_image_id
      config['package_id'] = retrieve_package_id
      unless config['image_id'].nil? \
        || config['package_id'].nil?

        self.save
      end
    end

    def create_server
      timestamp = Time.now.strftime("%Y.%m.%d-%H.%M.%S")
      connection.servers.create(
        name: "proxy-#{timestamp}-#{SecureRandom.uuid}",
        package: package_id,
        image: image_id
      )
    # Generally get this error when we've hit our limit on # of servers
    rescue Excon::Errors::Forbidden => e
      add_error(JSON.parse(e.response.body)['error_message'])
      NoServer
    end
  end
end
