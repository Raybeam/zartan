RSpec.describe Jobs::TargetedPerformanceAnalyzer do
  context '#perform' do

    it 'does a performance analysis on a specific site/proxy' do
      site = create(:site)
      proxy = create(:proxy)
      expect(Site).to receive(:find).and_return(site)
      expect(site).to receive(:proxy_performance_analysis!)

      Jobs::TargetedPerformanceAnalyzer.perform(site.id, proxy.id)
    end
  end
end
