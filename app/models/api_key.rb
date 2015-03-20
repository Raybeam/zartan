class ApiKey < ActiveRecord::Base
  before_create :generate_uid

  def generate_uid
    self.uuid = UUIDTools::UUID.random_create.to_s
  end
end
