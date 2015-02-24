class Source < ActiveRecord::Base
  has_many :proxies, dependent: :destroy, inverse_of: :source

  SourceConflict = Struct.new(:conflict_exists?)

  # Helper method for child classes to use to add a new proxy to the database
  # when the host and port have been created
  def add_proxy(host, port)
    proxy = Proxy.restore_or_initialize host: host, port: port

    return if self.fix_source_conflicts.conflict_exists?
    proxy.source = self

    proxy.save
  end

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

  # Pure virtual function intended for child classes to free the proxy resources
  def decommission_proxy(proxy)
    raise NotImplementedError, "Implement #{__callee__} in #{self.class.to_s}"
  end

  # Pure virtual function intended for child classes to create
  # the proxy resources
  def provision_proxies(num_proxies)
    raise NotImplementedError, "Implement #{__callee__} in #{self.class.to_s}"
  end
end
