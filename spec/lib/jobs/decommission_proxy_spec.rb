require 'jobs/decommission_proxy'

RSpec.describe Jobs::DecommissionProxy do
  context '#perform' do
    it 'tells the proxy to decommission itself' do
      proxy = create(:proxy)
      expect(Proxy).to receive(:find).and_return(proxy)
      expect(proxy).to receive(:decommission)
      expect(Jobs::DecommissionProxy.perform(proxy.id))
    end
  end
end
