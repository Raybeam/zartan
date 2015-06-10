class ApiLogging
  extend ActiveSupport::Concern
  
  API_LOGGER = ActiveSupport::TaggedLogging.new(Rails.logger)
  
  def api_log(record={})
    tm = Time.now
    record.merge!(timestamp: tm.strftime('%F %T'), unix_time: tm.to_i)
    ::ApiLogging::API_LOGGER.tagged('api') { |l| l.info(record.to_json) }
  end
end