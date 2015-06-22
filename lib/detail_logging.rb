module DetailLogging
  extend ActiveSupport::Concern
  
  API_LOGGER = ActiveSupport::TaggedLogging.new(Rails.logger)
  
  def detail_log(tag,record={})
    tm = Time.now
    record.merge!(timestamp: tm.strftime('%F %T'), unix_time: tm.to_i)
    ::DetailLogging::API_LOGGER.tagged(tag) { |l| l.info(record.to_json) }
  end
end