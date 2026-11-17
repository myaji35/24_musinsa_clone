module ApplicationHelper
  def admin_krw(amount) = "₩#{number_with_delimiter(amount.to_d.round)}"

  def staff_menu_links
    return [] unless mall_staff?

    links = [
      [ "재고관리", inventory_scan_path ],
      [ "대시보드", dashboard_index_path ],
      [ "주문 관리", admin_orders_path ],
      [ "거래처", suppliers_path ],
      [ "발주", purchase_orders_path ],
      [ "클레임", supplier_claims_path ],
      [ "상품 입고(엑셀)", supplier_imports_path ],
      [ "상품정보 입력", product_info_notices_path ]
    ]
    if mall_admin?
      links.concat([
        [ "판매현황", sales_path ],
        [ "상품분석", product_analyses_path ],
        [ "트렌드", trends_path ],
        [ "KPI", kpi_path ],
        [ "사용자 관리", admin_users_path ]
      ])
    end
    links
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
