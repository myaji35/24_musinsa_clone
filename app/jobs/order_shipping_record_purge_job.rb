class OrderShippingRecordPurgeJob < ApplicationJob
  queue_as :default

  def perform
    count = OrderShippingRecord.expired.delete_all
    Rails.logger.info("주문 배송 기록 파기 완료: #{count}건")
    count
  end
end
