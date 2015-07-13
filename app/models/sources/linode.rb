module Sources
  class Linode < Sources::Fog
    class << self
      def required_fields
        super.merge({
          api_key: :password,
          root_password: :password,
          image_name: :string,
          flavor_name: :string,
          kernel_name: :string,
          data_center_name: :string
        })
      end
    end

    ID_TYPES = ['image', 'flavor', 'kernel', 'data_center']

    # Connect to Linode to make sure our config is valid
    def validate_config!
      valid = false
      begin
        names_to_ids # Force re-evaluation of ids
        valid = (!image_id.nil? && !flavor_id.nil? && !kernel_id.nil? && !data_center_id.nil?)
      rescue Exception => e
        add_error(e.message)
      end
      valid
    end

    private

    # server_is_proxy_type?(server)
    # given a server, determine if it is running a proxy
    def server_is_proxy_type?(server)
      # Fog implenentation does not give access to flavor/image/etc data
      # So doing the most basic of checks here
      return server.name =~ /proxy/
   end

    def connection
      @connection ||= ::Fog::Compute.new(
        :provider => 'Linode',
        :linode_api_key => config['api_key']
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
        # flavor_id()
        # kernel_id()
        # data_center_id()
        # Get the image/flavor/kernel/data center id.
        # If the id is undefined, translate image/flavor/data center name to id by
        # connecting to Linode.
        # Returns cached value if already calculated
        # Parameters:
        #   None
        # Returns:
        #   - a numeric id representing the image/flavor/kernel/data center on Linode
        #   - nil if not found
        def #{id_type}_id
          key = '#{id_type}_id'
          return config[key] if config.has_key?(key)
          names_to_ids
          config[key]
        end

        # retrieve_image_id()
        # retrieve_flavor_id()
        # retrieve_kernel_id()
        # retrieve_data_center_id()
        # Retrieve image/flavor/kernel/data center id from Linode
        # If the id is not found then adds to the source's persistent error log
        # Parameters:
        #   None
        # Returns:
        #   - a numeric id representing the image/flavor/kernel/data center on Linode
        #   - nil if not found
        def retrieve_#{id_type}_id
          name = config['#{id_type}_name']

          if '#{id_type}' == 'image'
            id = connection.image_list.body["DATA"].find { |i| i["LABEL"] == name }["IMAGEID"]
            add_error "There is no #{id_type} named \#{name}." if id.nil?
          else
            id = connection.#{id_type.pluralize}.select do |i|
              if '#{id_type}' == 'data_center' then i.location == name
              else i.name == name end
            end.first.andand.id
            if id.nil?
              names = connection.#{id_type.pluralize}.map(&:name).join(", ")
              add_error "There is no #{id_type} named \#{name}. " \
                "Options are: \#{names}"
            end
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
      config['flavor_id'] = retrieve_flavor_id
      config['kernel_id'] = retrieve_kernel_id
      config['data_center_id'] = retrieve_data_center_id
      unless config['image_id'].nil? \
        || config['flavor_id'].nil? \
        || config['kernel_id'].nil? \
        || config['data_center_id'].nil?

        self.save
      end
    end

    def create_server
      # Linode restricts name to be no more than 50 chars
      name = "proxy-#{SecureRandom.uuid}"
      flavor = connection.flavors.get(config['flavor_id'])

      # Create Linode server
      server_id = connection.linode_create(config['data_center_id'], config['flavor_id'], 1).body['DATA']['LinodeID']
      connection.linode_update server_id, :label => name

      # Create disks
      swap_id = connection.linode_disk_create(server_id, "#{name}_swap", "ext4", 256).body['DATA']['DiskID']
      disk_id = connection.linode_disk_createfromimage(server_id, config['image_id'], "#{name}_main", (flavor.disk*1024)-256, config['root_password'], "").body['DATA']['DISKID']

      # Create config
      config_id = connection.linode_config_create(server_id, config['kernel_id'], name, "#{disk_id},#{swap_id},,,,,,,").body['DATA']['ConfigID']

      # Boot Linode server
      connection.linode_boot server_id, config_id

    rescue Exception => e
      connection.servers.get(server_id).destroy if !server_id.nil?
      add_error(e.message)
      NoServer
    end
  end
end
