class WechatPurchaseOrderJob < ApplicationJob
  queue_as :default

  def perform(purchase_order_id, sent_by_id = nil)
    Wechat::PurchaseOrderNotifier.call(PurchaseOrder.find(purchase_order_id), sent_by: User.find_by(id: sent_by_id))
  rescue StandardError
    Rails.logger.warn("위챗 발주 알림 작업 실패")
  end
end
