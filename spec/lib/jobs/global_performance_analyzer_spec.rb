RSpec.describe Jobs::GlobalPerformanceAnalyzer do
  context '#perform' do

    it 'does a performance analysis on every site' do
      sites = 2.times.map{|i| create(:site, name: i.to_s)}.each do |site|
        expect(site).to receive(:global_performance_analysis!)
      end
      expect(Site).to receive(:all).and_return(sites)

      Jobs::GlobalPerformanceAnalyzer.perform
    end
  end
end
