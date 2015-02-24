require 'spec_helper'
require 'lib/jobs/provision_proxies'

RSpec.describe ProvisionProxies do
  context '#perform' do
    Foo = Class.new(Source)
    Foo.create name: 'foo'
    proxies = [
      Proxy.new host: 'localhost', port: 8080,
      Proxy.new host: 'foobar.com', port: 80
    ]
    expect(Foo).to receive(provision_proxies).and_return(proxies)
    Site.create name: 'bar'

    expect(ProvisionProxies.perform('bar', Foo.to_s, ))
  end
end
