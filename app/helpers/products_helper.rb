module ProductsHelper
  PRODUCT_FORM_CATEGORIES = %w[상의 아우터 바지 원피스 스커트 가방 신발 액세서리].freeze

  def product_category_options(product)
    options = PRODUCT_FORM_CATEGORIES.map { |category| [ category, category ] }
    if product.category.present? && !PRODUCT_FORM_CATEGORIES.include?(product.category)
      options.unshift([ "#{product.category} (기존 값)", product.category ])
    end
    options
  end

  # 29cm 스타일 배지 시스템
  def product_badges(product)
    badges = []

    # 무료배송 배지
    badges << {
      text: "무료배송",
      class: "px-1.5 py-0.5 bg-gray-100 text-xs text-gray-700 font-medium rounded-sm"
    } if product.free_shipping?

    # 쿠폰 배지는 쿠폰 제도가 생길 때까지 띄우지 않는다(근거 없는 혜택 표시 금지)

    # 신상품 배지
    badges << {
      text: "신상",
      class: "px-1.5 py-0.5 bg-blue-100 text-xs text-blue-700 font-bold rounded-sm"
    } if product.new_arrival?

    # 재입고 배지
    badges << {
      text: "재입고",
      class: "px-1.5 py-0.5 bg-green-100 text-xs text-green-700 font-bold rounded-sm"
    } if product.restocked?

    badges
  end

  # 할인율 계산
  # Note: Product 모델에 discount_rate 컬럼 추가 시 product.discount_rate 반환
  # 현재는 기본 30% 고정 (무신사 스타일 UI 시연용)
  def discount_rate(product)
    return product.discount_rate if product.respond_to?(:discount_rate) && product.discount_rate.present?
    0 # 할인 정보가 없으면 할인 표시 안 함
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

  # 평점 계산 (평균 리뷰 점수)
  def average_rating(product)
    return 0 if product.reviews.empty?

    total = product.reviews.sum(:rating)
    (total.to_f / product.reviews.count).round(1)
  end

  # 평점 별 표시 (5점 만점)
  def rating_stars(rating)
    full_stars = rating.floor
    half_star = (rating - full_stars) >= 0.5
    empty_stars = 5 - full_stars - (half_star ? 1 : 0)

    stars = []
    stars += [ "★" ] * full_stars
    stars << "☆" if half_star
    stars += [ "☆" ] * empty_stars

    stars.join
  end

  # 상세페이지 본문의 "TODO: ..." 값 — 관리자에게는 무엇을 확인할지, 손님에게는 '확인 중'만 보인다 (ISS-142)
  def detail_value(value)
    text = value.to_s
    return text unless text.start_with?("TODO:")

    label = logged_in? ? "확인 필요 · #{text.delete_prefix('TODO:').strip}" : "확인 중"
    content_tag(:span, label, class: "inline-block px-2 py-0.5 text-xs font-bold bg-amber-100 text-amber-800", data: { todo: true })
  end

  # 배송·반품 규정(config/policies/returns.yml)
  def return_policy
    @return_policy ||= YAML.safe_load_file(Rails.root.join("config/policies/returns.yml"))
  end
end
