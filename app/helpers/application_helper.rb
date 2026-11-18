module ApplicationHelper
  def order_status_label(status)
    { "pending" => "입금 대기", "paid" => "결제 완료", "preparing" => "상품 준비", "shipped" => "배송 중", "delivered" => "배송 완료", "cancelled" => "취소", "refunded" => "환불" }.fetch(status, status)
  end

  def supplier_import_status_label(status)
    { "pending" => "대기", "processing" => "처리 중", "done" => "완료", "failed" => "실패" }.fetch(status, status)
  end

  def operator_menu_link(name, path)
    active = request.path == path || request.path.start_with?("#{path}/")
    link_to name, path, class: "text-ink hover:underline#{' font-bold underline' if active}", aria: { current: (active ? "page" : nil) }
  end

  # 가격 표기 단일 지점(DESIGN.md Typography/Price).
  # variant: :default(13px) | :lg(14px, 상세·합계)
  def price_won(amount, variant: :default, sale: false)
    classes = [ "price", ("price-lg" if variant == :lg), ("price-sale" if sale) ].compact.join(" ")
    tag.span("₩ #{number_with_delimiter(amount.to_i)}", class: classes)
  end

  def seoul_datetime(value)
    value.in_time_zone("Asia/Seoul").strftime("%Y-%m-%d %H:%M")
  end
end
