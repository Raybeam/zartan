module Concerns
  module SoftDeletable
    extend ActiveSupport::Concern

    included do
      scope :active, -> { where(deleted_at: nil) }
    end

    def active?
      self.deleted_at.nil?
    end
  end
end
