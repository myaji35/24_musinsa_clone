module Wechat
  class PurchaseOrderNotifier
    def self.call(purchase_order, sent_by: nil, client: Client.new)
      supplier = purchase_order.supplier
      # This deployment's official account belongs exclusively to JIEUM.
      return if supplier.account.wechat_channel_mode == "official" && supplier.account_id != Account.primary.id
      items = purchase_order.purchase_order_items
      quantity = items.sum(:quantity)
      due = purchase_order.expected_delivery_date&.iso8601 || "待定 / 미정"
      content = "新订单 / 신규 발주: #{purchase_order.order_number}\n品项 / 품목 수: #{items.count}\n总数量 / 총수량: #{quantity}\n交货日期 / 납기: #{due}\n请确认订单 / 발주를 확인해 주세요:\n#{purchase_order.confirmation_url}"
      data = { number: { value: purchase_order.order_number }, item_count: { value: items.count.to_s },
        quantity: { value: quantity.to_s }, delivery_date: { value: due } }
      supplier.wechat_contacts.for_account(supplier.account).find_each do |contact|
        client.send_text(contact: contact, content: content, purchase_order: purchase_order, sent_by: sent_by, template_data: data)
      end
    end

    def self.enqueue(purchase_order, sent_by:)
      return unless purchase_order.supplier.wechat_contacts.exists?
      WechatPurchaseOrderJob.perform_later(purchase_order.id, sent_by&.id)
    rescue StandardError
      Rails.logger.warn("위챗 발주 알림 작업 등록 실패")
    end
  end
end
