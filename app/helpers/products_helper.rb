module ProductsHelper
  # 29cm 스타일 배지 시스템
  def product_badges(product)
    badges = []

    # 무료배송 배지
    badges << {
      text: "무료배송",
      class: "px-1 py-0.5 bg-gray-100 text-[9px] text-gray-500 font-medium rounded-sm"
    } if product.free_shipping?

    # 쿠폰 배지
    badges << {
      text: "쿠폰",
      class: "px-1 py-0.5 bg-red-100 text-[9px] text-red-600 font-bold rounded-sm"
    } if product.has_coupon?

    # 신상품 배지
    badges << {
      text: "신상",
      class: "px-1 py-0.5 bg-blue-100 text-[9px] text-blue-600 font-bold rounded-sm"
    } if product.new_arrival?

    # 재입고 배지
    badges << {
      text: "재입고",
      class: "px-1 py-0.5 bg-green-100 text-[9px] text-green-600 font-bold rounded-sm"
    } if product.restocked?

    badges
  end

  # 할인율 계산 (임시로 30% 고정, 추후 실제 할인 로직 구현)
  def discount_rate(product)
    30 # TODO: 실제 할인율 계산 로직 구현
  end

  # 할인가 계산
  def discounted_price(product)
    product.price * (100 - discount_rate(product)) / 100
  end

  # 29cm 스타일 큐레이션 제목 생성
  def mood_to_title(mood)
    titles = {
      "delicate" => "섬세함으로 빚어낸",
      "casual" => "편안한 일상을 위한",
      "minimal" => "미니멀리즘의 정수",
      "vintage" => "시간이 만든 가치",
      "modern" => "현대적 감각의"
    }
    titles[mood] || mood
  end

  def mood_to_description(mood)
    descriptions = {
      "delicate" => "세밀한 디테일이 돋보이는 아이템",
      "casual" => "자연스럽게 스타일을 완성하는",
      "minimal" => "군더더기 없는 깔끔한 라인",
      "vintage" => "클래식한 멋을 간직한",
      "modern" => "트렌디한 감성을 담은"
    }
    descriptions[mood] || ""
  end
end
