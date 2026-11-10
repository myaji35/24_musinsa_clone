module ApplicationHelper
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
