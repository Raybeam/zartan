class Source < ActiveRecord::Base
  has_many :proxies, dependent: :destroy, inverse_of: :source

  SourceConflict = Struct.new(:conflict_exists?)

  def add_proxy(host, port)
    proxy = Proxy.restore_or_initialize host: host, port: port

    return proxy if self.fix_source_conflicts.conflict_exists?
    self.proxies << proxy

    proxy.save
  end

  def fix_source_conflicts(proxy)
    conflict = SourceConflict.new false
    if !proxy.source.nil?
      && proxy.source != self

      if proxy.source.reliability < self.reliability
        proxy.source.decommission_proxy(proxy)
      else
        self.decommission_proxy(proxy)
        conflict.conflict_exists? = true
      end
    end
    conflict
  end

  # Pure virtual function intended for child classes to free the proxy resources
  def decommission_proxy(proxy)
    raise NotImplementedError, "Implement #{__callee__} in #{self.class.to_s}"
  end

  # Create more proxies using source-specific code, then attach them
  # to the source database object
  def provision_proxies(num_proxies)
    proxies = self._provision_proxies num_proxies
    self << *proxies
    self.save
  end

  # Pure virtual function intended for child classes to create
  # the proxy resources
  def _provision_proxies(num_proxies)
    raise NotImplementedError, "Implement #{__callee__} in #{self.class.to_s}"
  end
end
