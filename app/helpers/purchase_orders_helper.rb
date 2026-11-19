module PurchaseOrdersHelper
  def purchase_order_status_label(status)
    { "draft" => "작성 중", "submitted" => "제출됨", "confirmed" => "확정됨",
      "partially_received" => "일부 입고", "received" => "입고됨", "cancelled" => "취소됨" }.fetch(status, status)
  end
  def purchase_order_status_badge_class(status)
    case status
    when "draft" then "bg-gray-100 text-gray-800"
    when "submitted" then "bg-yellow-100 text-yellow-800"
    when "confirmed", "partially_received" then "bg-blue-100 text-blue-800"
    when "received" then "bg-green-100 text-green-800"
    when "cancelled" then "bg-red-100 text-red-800"
    end
  end
end
