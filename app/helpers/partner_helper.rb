module PartnerHelper
  def partner_order_status(status)
    { "draft" => "초안", "submitted" => "확정 대기", "confirmed" => "확정", "received" => "입고완료", "cancelled" => "취소" }[status]
  end
end
