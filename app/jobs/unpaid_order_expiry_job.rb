class UnpaidOrderExpiryJob < ApplicationJob
  queue_as :default

  def perform
    unless ENV["ORDER_AUTO_CANCEL_ENABLED"] == "1"
      Rails.logger.info("미입금 주문 자동 취소가 비활성화되어 있습니다")
      return
    end

    instruction = PaymentInstruction.new
    today = Time.current.in_time_zone("Asia/Seoul").to_date
    Order.pending.find_each do |order|
      order.with_lock do
        order.cancel! if order.status == "pending" && instruction.due_on(order.created_at) < today
      end
    end
  end
end
