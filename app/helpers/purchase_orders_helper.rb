module PurchaseOrdersHelper
  def purchase_order_status_label(status)
    { "draft" => "작성 중", "submitted" => "제출됨", "confirmed" => "확정됨",
      "received" => "입고됨", "cancelled" => "취소됨" }.fetch(status, status)
  end
end
