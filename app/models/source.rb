class Source < ActiveRecord::Base
  has_many :proxies, dependent: :destroy, inverse_of: :source

  before_validation :save_config

  # Redis-backed properties
  include Redis::Objects
  list :persistent_errors

  # Ensure all of the necessary configuration options are set
  validate do |source|
    conf = source.config
    source.class.required_fields.each_key do |field_name|
      unless conf.has_key? field_name.to_s and conf[field_name.to_s].present?
        source.errors[:config] << "must contain a '#{field_name}' property."
      end
    end
  end

  # Dummy class used to add proxies to the database without adding them to a
  # site
  class NoSite
    def self.add_proxies(*args)
    end
  end

  def config
    @config ||= JSON.parse(read_attribute(:config))
  end
  
  def config=(new_value)
    @config = new_value
  end

  def save_config
    write_attribute(:config, @config.to_json) if @config
  end
  
  SourceConflict = Struct.new(:conflict_exists?)

  # Pure virtual function intended for child classes to free the proxy resources
  # Parameters:
  #   proxy - The proxy object that is to be decommissioned
  def decommission_proxy(proxy)
    raise NotImplementedError, "Implement #{__callee__} in #{self.class.to_s}"
  end

  # Pure virtual function intended for child classes to create
  # the proxy resources
  # Parameters:
  #   num_proxies - How many proxies to create
  #   site - what site to add the proxies to after they're created
  def provision_proxies(num_proxies, site)
    raise NotImplementedError, "Implement #{__callee__} in #{self.class.to_s}"
  end

  # Enqueues a ProvisionProxies job to create up to num_proxies new proxies.
  # Returns the number of new proxies that should be created after the provision
  def enqueue_provision(site:, num_proxies:)
    return 0 if num_proxies <= 0 || self.proxies.active.length >= self.max_proxies
    desired_proxy_count = self.desired_proxy_count(num_proxies)
    Resque.enqueue_to(self.class.queue, Jobs::ProvisionProxies,
      site.id, self.id, desired_proxy_count
    )
    desired_proxy_count - self.proxies.active.length
  end

  # Pure virtual function intended for child classes to
  # test the saved config by connecting to the remote source.
  # Not part of standard validation because of external dependency
  def validate_config!
    raise NotImplementedError, "Implement #{__callee__} in #{self.class.to_s}"
  end

  # return the number of proxies that would exist if up to num_requested
  # proxies were provisioned
  def desired_proxy_count(num_requested)
    [self.max_proxies, self.proxies.active.length + num_requested].min
  end

  protected

  # Helper method for child classes to use to add a new proxy to the database
  # when the host and port have been created
  def add_proxy(host, port, site = NoSite)
    proxy = Proxy.restore_or_initialize host: host, port: port

    return if fix_source_conflicts(proxy).conflict_exists?
    proxy.source = self
    proxy.save
    site.add_proxies(proxy)
  end

  # If a systemic error occurs while provisioning proxies then it gets
  # reported here
  def add_error(error_string)
    persistent_errors << error_string
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
    # queue()
    # Each source gets its own queue for provisioning and decommissioning
    # proxies.  Get the name of that queue as a string
    def queue
      # Keeps only the portion after the last slash
      self.name.underscore.split(%r[/]).last
    end

    def required_fields
      raise NotImplementedError, "Implement #{__callee__} in #{self.to_s}"
    end
    
    def display_name
      # The default implementation of ##display_name takes the name of the class
      # minus any module names, and attempts to convert it into mutliple words
      #   ex.: Sources::DigitalOcean.display_name == "Digital Ocean"
      self.name.underscore.split(%r[/]).last.split(%r[_]).collect(&:capitalize).join ' '
    end
  end
end
