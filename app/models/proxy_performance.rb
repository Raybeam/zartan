class ProxyPerformance < ActiveRecord::Base
  belongs_to :proxy, inverse_of: :proxy_performances
  belongs_to :site, inverse_of: :proxy_performances

  include Concerns::SoftDeletable

  class << self
    def restore_or_create(site:, proxy:)
      perform = ProxyPerformance.find_or_create_by(
        :site => site, :proxy => proxy
      )
      perform.deleted_at = nil
      perform.times_succeeded = 0
      perform.times_failed = 0
      perform.reset_at = nil
      perform.save
      perform
    end
  end

  def increment(times_succeeded: 0, times_failed: 0)
    self.times_succeeded += times_succeeded
    self.times_failed += times_failed
    self.save
  end
end
