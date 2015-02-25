require 'rails_helper'

RSpec.describe Source, type: :model do

  let(:source) {create(:blank_source)}
  let(:proxy) {create(:proxy)}

  context '#add_proxy' do
    before(:each) do
      expect(Proxy).to receive(:restore_or_initialize).and_return(proxy)
    end

    it 'adds a proxy' do
      conflict = double(:conflict_exists? => false)
      expect(source).to receive(:fix_source_conflicts).and_return(conflict)

      source.add_proxy(proxy.host, proxy.port)
      expect(proxy.source).to be source
    end

    it 'does nothing if the proxy is already in the database' do
      conflict = double(:conflict_exists? => true)
      expect(source).to receive(:fix_source_conflicts).and_return(conflict)

      source.add_proxy(proxy.host, proxy.port)
      expect(proxy.source).to_not be source
    end
  end

  context '#fix_source_conflicts' do
    it 'does nothing if we are already the source' do
      proxy.source = source
      proxy.save

      expect(source.fix_source_conflicts(proxy).conflict_exists?).to be_falsey
    end

    it 'transfers ownership of the proxy to self if old source is bad' do
      worse_source = create(:blank_source, :reliability => source.reliability-1)
      proxy.source = worse_source
      proxy.save

      expect(worse_source).to receive(:decommission_proxy)
      expect(source).to receive(:decommission_proxy).never
      expect(source.fix_source_conflicts(proxy).conflict_exists?).to be_falsey
    end

    it 'keeps ownership of the proxy on other source if old source is good' do
      better_source = create(:blank_source, :reliability => source.reliability+1)
      proxy.source = better_source
      proxy.save

      expect(better_source).to receive(:decommission_proxy).never
      expect(source).to receive(:decommission_proxy)
      expect(source.fix_source_conflicts(proxy).conflict_exists?).to be_truthy
    end
  end
end
