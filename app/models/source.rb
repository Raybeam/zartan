class Source < ActiveRecord::Base
  has_many :proxies, dependent: :destroy, inverse_of: :source
  
  # Ensure all of the necessary configuration options are set
  validate do |source|
    conf = source.config
    source.class.required_fields.each_key do |field_name|
      unless conf.has_key? field_name.to_s
        source.errors[:config] << "must contain a '#{field_name}' property."
      end
    end
  end

  def config
    JSON.parse(read_attribute(:config))
  end
  
  def config=(new_value)
    write_attribute(:config, new_value.to_json)
  end
  
  SourceConflict = Struct.new(:conflict_exists?)

  # Pure virtual function intended for child classes to free the proxy resources
  def decommission_proxy(proxy)
    raise NotImplementedError, "Implement #{__callee__} in #{self.class.to_s}"
  end

  # Pure virtual function intended for child classes to create
  # the proxy resources
  def provision_proxies(num_proxies)
    raise NotImplementedError, "Implement #{__callee__} in #{self.class.to_s}"
  end

  # Enqueues a ProvisionProxies job to create up to num_proxies new proxies.
  # Returns the number of new proxies that should be created after the provision
  def enqueue_provision(site:, num_proxies:)
    return 0 if num_proxies <= 0 || self.proxies.length == self.max_proxies
    desired_proxy_count = self.desired_proxy_count(num_proxies)
    Resque.enqueue(Jobs::ProvisionProxies,
      site.id, self.id, desired_proxy_count
    )
    desired_proxy_count - self.proxies.length
  end

  # return the number of proxies that would exist if up to num_requested
  # proxies were provisioned
  def desired_proxy_count(num_requested)
    [self.max_proxies, self.proxies.length + num_requested].min
  end

  protected

  # Helper method for child classes to use to add a new proxy to the database
  # when the host and port have been created
  def add_proxy(host, port)
    proxy = Proxy.restore_or_initialize host: host, port: port

    return if fix_source_conflicts(proxy).conflict_exists?
    proxy.source = self

    proxy.save
  end

  private

  # Checks the database to see if the given proxy already exists
  # and has a source.  If it does then conflicts are resolved based on the
  # source's reliability
  #
  # Returns:
  # SourceConflict object.  This object has one method, :conflict_exists?
  # This method evaluates to true if the proxy already exists in the database
  # with a source that has a reliability greater than or equal to self.
  def fix_source_conflicts(proxy)
    conflict = SourceConflict.new false
    if !proxy.source.nil? \
      && proxy.source != self

      if proxy.source.reliability < self.reliability
        proxy.source.decommission_proxy(proxy)
      else
        self.decommission_proxy(proxy)
        conflict[:conflict_exists?] = true
      end
    end
    conflict
  end
  
  
  class << self
    def required_fields
      raise NotImplementedError, "Implement #{__callee__} in #{self.to_s}"
    end
    
    def display_name
      # The default implementation of ##display_name takes the name of the class
      # minus any module names, and attempts to convert it into mutliple words
      #   ex.: Sources::DigitalOcean.display_name == "Digital Ocean"
      self.name.underscore.split(%r[/]).last.split(%r[_]).collect(&:capitalize).join ' '
    end
    
    # Return a shared Array of source types.
    # Subclasses of Source can register themselves as an available source type
    # by including the following line in their definition:
    #     Source.source_types << self
    def source_types
      @source_types ||= []
    end
  end
end
