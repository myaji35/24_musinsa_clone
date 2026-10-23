module ProductsHelper
  PRODUCT_FORM_CATEGORIES = %w[상의 아우터 바지 원피스 스커트 가방 신발 액세서리].freeze

  def product_category_label(product)
    category = product.category.to_s
    { "Outer" => "아우터", "One-piece" => "원피스" }[category] ||
      (category if category.match?(/[가-힣]/) && !category.match?(/[A-Za-z]/))
  end

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

  # 카탈로그 착용컷의 고해상도 짝(<shot>-1440.webp)이 있으면 srcset 을 붙인다 — 카드는 720 JPEG, 큰 화면·레티나는 1440 WebP
  def catalog_srcset(url)
    large = url.to_s.sub(/\.jpg\z/, "-1440.webp")
    return unless large != url && Rails.public_path.join(large.delete_prefix("/")).exist?

    "#{url} 720w, #{large} 1440w"
  end

  def catalog_image_tag(url, sizes: "(min-width: 1024px) 600px, 100vw", **options)
    image_tag url, srcset: catalog_srcset(url), sizes: (sizes if catalog_srcset(url)), **options
  end

  # 카탈로그 색상명 → 스와치 색(두 색 이름은 반반)
  SWATCHES = {
    "카멜" => "#B98A57", "카멜브라운" => "#8E6240", "브라운베이지" => "#A68A6D", "다크브라운" => "#4A3226",
    "초콜릿브라운" => "#3F2A1E", "베이지" => "#D8C3A5", "토프" => "#8B7D6B", "그레이지" => "#B8B0A2",
    "라이트그레이" => "#C9C9C9", "차콜" => "#3A3F45", "블랙" => "#111111", "네이비" => "#1F2A44",
    "아이보리" => "#F4EFE3", "카키" => "#6B6B47", "다크카키" => "#4F4F35", "버건디" => "#6D1A2A",
    "옐로" => "#E2C044", "베이비핑크" => "#F2C6CC"
  }.freeze

  def color_swatch(name)
    return "linear-gradient(135deg,#111 50%,#f5f5f5 50%)" if name == "블랙화이트"

    SWATCHES.fetch(name, "#D1D5DB")
  end

  # 도착 예정일(영업일 2~3일, 주말 제외) 예: 10/24(금)~10/26(일)
  def delivery_eta(from = Date.current)
    days = (1..10).map { |n| from + n }.reject { |day| day.saturday? || day.sunday? }
    first, last = days[1], days[2]
    wd = %w[일 월 화 수 목 금 토]
    "#{first.strftime('%-m/%-d')}(#{wd[first.wday]})~#{last.strftime('%-m/%-d')}(#{wd[last.wday]})"
  end

  # 매거진 이미지 경로(카탈로그 컷)
  def catalog_shot_url(product_id, shot)
    "/catalog/#{product_id}/#{shot}.jpg"
  end
end
