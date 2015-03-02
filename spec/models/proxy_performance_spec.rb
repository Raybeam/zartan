require 'rails_helper'

RSpec.describe ProxyPerformance, type: :model do
  let(:site) {create(:site)}
  let(:proxy) {create(:proxy)}
  let(:proxy_performance) do
    ProxyPerformance.create(:proxy => proxy, :site => site)
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
  end
end
