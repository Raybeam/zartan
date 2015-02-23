class Source < ActiveRecord::Base
  has_many :proxies, dependent: :destroy, inverse_of: :source

  def add_proxy(host, port)
    proxy = Proxy.restore_or_initialize host: host, port: port

    if !proxy.source.nil?
      && proxy.source != self
      && proxy.source.reliability < self.reliability

      proxy.source.decomission_proxy(proxy)
    end
    self.proxies << proxy

    proxy.save
  end

  def decomission_proxy
    raise NotImplementedError, "Implement #{__callee__} in #{self.class.to_s}"
  end
end
