RSpec.describe SourcePerformance do
  let(:source) {create(:blank_source)}
  let(:site) {create(:site)}
  let(:source_performance) {SourcePerformance.new(:site => site, :source => source)}
  let(:proxy1) {create(:proxy, :source => source)}
  let(:proxy2) {create(:proxy, :source => source, :host => 'alternate.com')}
  let(:performance1) {ProxyPerformance.new(:proxy => proxy1, :site => site)}
  let(:performance2) {ProxyPerformance.new(:proxy => proxy2, :site => site)}

  context '#success_ratio' do
    it 'Calculates the success ratio for an entire site' do
      performance1.times_succeeded = 5
      performance1.times_failed = 6
      performance1.save
      performance2.times_succeeded = 20
      performance2.times_failed = 0
      performance2.save

      expect(source_performance.success_ratio).to eq 25.0/31
    end

    it 'calculates a perfect success ratio if there are no proxies' do
      performance1.save
      performance2.save
      expect(source_performance.success_ratio).to eq 1.0
    end

    it 'calculates a perfect success ratio if there are no counts' do
      expect(source_performance.success_ratio).to eq 1.0
    end
  end
end
