RSpec.describe Jobs::AddSiteProxies do
  context '#perform' do
    it 'tells the ProxyRequestor to find more proxies' do
      site = create(:site)
      proxy_requestor = double
      expect(ProxyRequestor).to receive(:new).and_return proxy_requestor
      expect(proxy_requestor).to receive(:run)

      Jobs::AddSiteProxies.perform(site.id)
    end
  end
end
