RSpec.describe Jobs::ProvisionProxies do
  context '#perform' do
    it 'performs' do
      site = create(:site)
      expect(Site).to receive(:find).and_return(site)
      source = create(:blank_source)
      expect(Source).to receive(:find).and_return(source)
      proxies = [
        create(:proxy, host: 'localhost', port: 8080),
        create(:proxy, host: 'foobar.com', port: 80)
      ]
      expect(source).to receive(:provision_proxies).and_return(proxies)

      expect(Jobs::ProvisionProxies.perform(site.id, source.id, 2))

      expect(site.proxies.length).to eq 2
    end
  end
end
