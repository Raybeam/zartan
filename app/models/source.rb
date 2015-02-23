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
        proxy.source.decomission_proxy(proxy)
      else
        self.decomission_proxy(proxy)
        conflict.conflict_exists? = true
      end
    end
    conflict
  end

  def decomission_proxy
    raise NotImplementedError, "Implement #{__callee__} in #{self.class.to_s}"
  end
end
