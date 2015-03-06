RSpec.describe Jobs::ProvisionProxies do
  context '#perform' do
    let(:site) {create(:site)}
    let(:source) {create(:digital_ocean_source)}

    it 'previsions proxies and adds them to the site' do
      expect(Site).to receive(:find).and_return(site)
      expect(Source).to receive(:find).and_return(source)
      proxies = [
        create(:proxy, host: 'localhost', port: 8080),
        create(:proxy, host: 'foobar.com', port: 80)
      ]
      expect(source).to receive(:provision_proxies).and_return(proxies)

      Jobs::ProvisionProxies.perform(site.id, source.id, 2)
    end

    it "does nothing if we don't actually need to create more proxies" do
      source.proxies << create(:proxy)
      source.save
      expect(Source).to receive(:find).and_return(source)
      expect(source).to receive(:provision_proxies).never

      Jobs::ProvisionProxies.perform(site.id, source.id, 1)
    end
  end
end
