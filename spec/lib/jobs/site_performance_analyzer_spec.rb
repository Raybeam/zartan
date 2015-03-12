RSpec.describe Jobs::SitePerformanceAnalyzer do
  context '#perform' do
    let(:site) {create(:site)}

    it 'does a performance analysis on a single site' do
      expect(Site).to receive(:find).and_return(site)
      expect(site).to receive(:global_performance_analysis!)

      Jobs::SitePerformanceAnalyzer.perform site.id
    end
  end
end
