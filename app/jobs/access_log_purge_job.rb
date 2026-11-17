class AccessLogPurgeJob < ApplicationJob
  queue_as :default

  def perform
    count = AccessLog.expired.delete_all
    Rails.logger.info("접속기록 파기 완료: #{count}건")
    count
  end
end
