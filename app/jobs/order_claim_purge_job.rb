class OrderClaimPurgeJob < ApplicationJob
  queue_as :default

  def perform
    count = OrderClaim.where(status: %w[completed rejected]).where("processed_at < ?", Rails.configuration.x.order_claim_retention_years.years.ago).delete_all
    Rails.logger.info("주문 클레임 파기 완료: #{count}건")
    count
  end
end
