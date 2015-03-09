require 'rails_helper'

RSpec.describe ProxyPerformance, type: :model do
  let(:site) {create(:site)}
  let(:proxy) {create(:proxy)}
  let(:proxy_performance) do
    @proxy_performance ||= ProxyPerformance.create(
      :proxy => proxy, :site => site
    )
  end

  context '#restore_or_create' do
    after :each do
      proxy_performance.reload
      expect(proxy_performance.id).to eq 1
      expect(proxy_performance.deleted_at).to be_nil
      expect(proxy_performance.times_succeeded).to eq 0
      expect(proxy_performance.times_failed).to eq 0
      expect(proxy_performance.reset_at).to be_nil
    end

    it 'restores an existing ProxyPerformance object' do
      proxy_performance.soft_delete
      proxy_performance.save

      returned_perform = ProxyPerformance.restore_or_create(
        site: site, proxy: proxy
      )

      expect(returned_perform.id).to eq proxy_performance.id
    end

    it 'creates a new ProxyPerformance object' do
      @proxy_performance = ProxyPerformance.restore_or_create(
        site: site, proxy: proxy
      )
    end
  end

  context '#increment' do
    it 'increments initial performance metrics' do
      times_succeeded = 1
      times_failed = 4

      proxy_performance.increment(
        times_succeeded: times_succeeded,
        times_failed: times_failed
      )

      expect(proxy_performance.times_succeeded).to eq times_succeeded
      expect(proxy_performance.times_failed).to eq times_failed
    end

    it 'increments existing performance metrics' do
      initial_times_succeeded = 7
      initial_times_failed = 2
      proxy_performance.times_succeeded = initial_times_succeeded
      proxy_performance.times_failed = initial_times_failed
      proxy_performance.save
      times_succeeded = 1
      times_failed = 4

      proxy_performance.increment(
        times_succeeded: times_succeeded,
        times_failed: times_failed
      )

      expect(proxy_performance.times_succeeded).to eq (
        initial_times_succeeded + times_succeeded
      )
      expect(proxy_performance.times_failed).to eq (
        initial_times_failed + times_failed
      )
    end

    it 'does nothing with default parameters' do
      proxy_performance.increment

      expect(proxy_performance.times_succeeded).to eq 0
      expect(proxy_performance.times_failed).to eq 0
    end
  end
end
