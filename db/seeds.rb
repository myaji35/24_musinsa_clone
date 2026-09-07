
# Clear existing data
ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = OFF")
PurchaseOrderItem.destroy_all
PurchaseOrder.destroy_all
Supplier.destroy_all
Campaign.destroy_all
Notification.destroy_all
Order.destroy_all
AnonyCustomer.destroy_all
StockLog.destroy_all
Variant.destroy_all
Review.destroy_all
SnapProduct.destroy_all
Snap.destroy_all
Product.destroy_all
User.destroy_all
ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = ON")
puts "✅ Cleared existing data"

products_data = [
  {
    "name": "[골드원사/하객룩/모임룩]코렌다 벨트 트위드 원피스[단독특가]",
    "price": 55800,
    "image_url": "https://shopping-phinf.pstatic.net/main_5818657/58186579277.jpg?type=f300",
    "brand": "시크라인",
    "category": "One-piece"
  },
  {
    "name": "디애이치 코렌 레이어드 원피스",
    "price": 30800,
    "image_url": "https://shopping-phinf.pstatic.net/main_2794398/27943988468.20210710214327.jpg?type=f300",
    "brand": "Coren",
    "category": "One-piece"
  },
  {
    "name": "매니크 코렌 울 니트 레이어드 원피스",
    "price": 39520,
    "image_url": "https://shopping-phinf.pstatic.net/main_5772781/57727811984.20251112001853.jpg?type=f300",
    "brand": "Coren",
    "category": "One-piece"
  },
  {
    "name": "코렌 플라워 퍼프 미니 원피스 백 세트",
    "price": 55000,
    "image_url": "https://shopping-phinf.pstatic.net/main_5762598/57625982518.jpg?type=f300",
    "brand": "트렌디어패럴",
    "category": "One-piece"
  },
  {
    "name": "코렌 끈 원피스 3컬러 린넨 100%",
    "price": 61000,
    "image_url": "https://shopping-phinf.pstatic.net/main_8199348/81993482391.jpg?type=f300",
    "brand": "이야기가 있는 풍경",
    "category": "One-piece"
  },
  {
    "name": "다이앤본퍼스텐버그 코렌 리버시블 프린트 스트레치 메시 원피스 스카이블루 시밀러 룩 바캉스",
    "price": 334990,
    "image_url": "https://shopping-phinf.pstatic.net/main_5732329/57323293135.jpg?type=f300",
    "brand": "Coren",
    "category": "One-piece"
  },
  {
    "name": "다이앤본퍼스텐버그 코렌 리버시블 프린트 스트레치 메시 원피스 스카이블루 시밀러 룩 바캉스",
    "price": 313740,
    "image_url": "https://shopping-phinf.pstatic.net/main_9010993/90109933928.jpg?type=f300",
    "brand": "블랙유로",
    "category": "One-piece"
  },
  {
    "name": "[완전강추]빅사이즈 코렌 코듀로이 뷔스티에 프릴 롱 원피스",
    "price": 52300,
    "image_url": "https://shopping-phinf.pstatic.net/main_8710974/87109740839.jpg?type=f300",
    "brand": "에브리바레",
    "category": "One-piece"
  },
  {
    "name": "다이앤 본 퍼스텐버그 코렌 리버시블 프린트 스트레치 메시 원피스",
    "price": 346600,
    "image_url": "https://shopping-phinf.pstatic.net/main_5732342/57323425679.jpg?type=f300",
    "brand": "Coren",
    "category": "One-piece"
  },
  {
    "name": "휴양지 코렌 플레어 슬리브 드레스",
    "price": 68100,
    "image_url": "https://shopping-phinf.pstatic.net/main_8545806/85458066269.jpg?type=f300",
    "brand": "제니직구",
    "category": "One-piece"
  }
]

# Create 20 products using the Generated Model Variations
brands_list = [ "COVERNAT", "THISISNEVERTHAT", "LEE", "MUSINSA STANDARD", "ANDERSSON BELL", "MARD MERCREDI", "WHAT IT ISNT", "GROOVE RHYME", "PARTIMENTO", "DRAW FIT" ]

# Define Image Mapping based on Category or Rotation
# Define Image Mapping with Matching Names/Categories
model_variations = [
  { image: "/model_fitting.jpg", name_suffix: "Premium Grey Wool Coat", category: "Outer" },
  { image: "/model_tweed_dress.png", name_suffix: "Luxury Tweed One-piece", category: "One-piece" },
  { image: "/model_navy_coat.png", name_suffix: "Classic Navy Cashmere Coat", category: "Outer" },
  { image: "/model_knit_sweater.png", name_suffix: "Soft White Knit Sweater", category: "Top" }
]

20.times do |i|
  source_item = products_data[i % products_data.length]

  # Cycle strictly through the 4 variations to ensure all 4 are visible
  variation = model_variations[i % 4]

  # Construct a name that matches the image
  # We keep the brand from the source list for variety, but override the product name/category
  brand_name = brands_list[i % brands_list.length]

  # AI 속성 정의 (29cm 스타일 큐레이션용)
  moods = [ "minimal", "casual", "delicate", "vintage", "modern" ]
  tpos = [ "daily", "office", "date", "party", "casual" ]
  fit_styles = [ "slim", "regular", "oversized", "loose" ]
  material_feels = [ "soft", "structured", "lightweight", "warm" ]

  ai_attrs = {
    "mood" => [ moods.sample ],
    "tpo" => [ tpos.sample ],
    "fit_style" => fit_styles.sample,
    "material_feel" => material_feels.sample
  }

  # 배지 정의
  badge_array = []
  badge_array << "coupon" if i % 3 == 0

  Product.create!(
    name: "#{brand_name} #{variation[:name_suffix]}",
    description: "Exclusive fitting by our main model. Premium quality from #{brand_name}. This item features our signature #{variation[:category]} design.",
    price: source_item[:price], # Keep realistic prices
    stock: rand(10..100),
    category: variation[:category],
    brand: brand_name,
    gender: 'Women',
    views_count: rand(100..10000),
    sales_count: 50 + rand(10..1000),
    image_url: variation[:image],
    ai_attributes: ai_attrs,
    badges: badge_array,
    is_new: i < 5, # 처음 5개는 신상
    restocked_at: (i % 7 == 0 ? 3.days.ago : nil) # 7의 배수는 재입고
  )
end

puts "Created #{Product.count} products (Attributes by AI Model Generation)"

# 개발용 관리자 계정 (샘플 리뷰와 스냅 작성자)
user = User.create!(email: "admin@jieun.test", name: "관리자", password: "JieunDev!2026")

# Add sample reviews
Product.all.each do |product|
  rand(0..5).times do
    Review.create!(
      product: product,
      user: user,
      content: [ "모델핏이 너무 예뻐서 샀어요!", "사진이랑 똑같네요.", "고급스러워 보입니다.", "재질 만족합니다.", "핏이 예술이네요." ].sample,
      rating: rand(4..5),
      height: rand(155..175),
      weight: rand(45..65),
      size_purchased: [ 'S', 'M', 'Free' ].sample,
      photo_url: nil
    )
  end
end
puts "Added sample reviews"

# Create dummy snaps using the SAME Model Images
10.times do |i|
  source_item = products_data[i % products_data.length]
  variation = model_variations.sample # Random snap image

  Snap.create!(
    user: user,
    content: "모델 착장 그대로 구매! #{[ '#데일리룩', '#하객룩', '#데이트룩' ].sample} #Coren #{source_item[:name]} #OOTD",
  )
end
puts "Created sample snaps"

# ========================================
# Phase 2: Epic 4, 5, 6 샘플 데이터
# ========================================

# Epic 4.1: AnonyCustomer & Order 생성
puts "\n📦 Epic 4.1: 익명 고객 및 주문 생성 중..."

zip_prefixes = [ "060", "135", "411", "463", "612" ] # 서울, 강남, 경기, 부산, 광주
birth_years = (1985..2005).to_a

20.times do |i|
  customer = AnonyCustomer.create!(
    zip_prefix: zip_prefixes.sample,
    phone_suffix: sprintf("%04d", rand(1000..9999)),
    birth_year: birth_years.sample,
    preference_tags: {}
  )

  # 각 고객마다 1~3개 주문 생성
  rand(1..3).times do
    product = Product.all.sample
    variant = product.variants.first || product.variants.create!(
      color: [ "Black", "White", "Navy", "Grey" ].sample,
      size: [ "S", "M", "L" ].sample,
      stock: rand(5..50),
      min_stock: 10
    )

    Order.create!(
      anony_customer: customer,
      product: product,
      variant: variant,
      quantity: rand(1..2),
      total_price: product.price * rand(1..2),
      status: [ "delivered", "shipped", "paid" ].sample
    )
  end
end

puts "✅ 생성 완료: AnonyCustomer #{AnonyCustomer.count}명, Order #{Order.count}건"

# Epic 4.2: Variant 생성 (재고 관리용)
puts "\n📦 Epic 1.3 & 2: Variant 및 StockLog 생성 중..."

Product.all.each do |product|
  next if product.variants.any? # 이미 생성된 경우 스킵

  [ "Black", "White", "Navy" ].each do |color|
    [ "S", "M", "L" ].each do |size|
      variant = Variant.create!(
        product: product,
        color: color,
        size: size,
        stock: rand(0..30), # 일부는 재고 부족
        min_stock: 10
      )

      # 입고 이력 생성
      StockLog.create!(
        variant: variant,
        log_type: "in",
        quantity: rand(10..50),
        supplier: [ "동대문 도매", "남대문 시장", "이랜드", "코오롱" ].sample,
        unit_cost: product.price * 0.6,
        note: "초기 입고"
      )
    end
  end
end

puts "✅ 생성 완료: Variant #{Variant.count}개, StockLog #{StockLog.count}건"

# Epic 5.1: Notification 생성 (재고 부족 알림)
puts "\n📧 Epic 5.1: 재고 부족 알림 생성 중..."

low_stock_variants = Variant.where("stock <= min_stock")
low_stock_variants.first(5).each do |variant|
  Notification.create!(
    variant: variant,
    notification_type: "low_stock",
    message: "⚠️ [긴급] #{variant.product.name} (#{variant.color}/#{variant.size}) 재고 부족: 현재 #{variant.stock}개",
    status: [ "sent", "pending" ].sample,
    sent_at: [ Time.current, nil ].sample
  )
end

puts "✅ 생성 완료: Notification #{Notification.count}건"

# Epic 6.1: Campaign 생성
puts "\n📢 Epic 6.1: 마케팅 캠페인 생성 중..."

[ "new_arrival", "restock", "personalized", "seasonal" ].each_with_index do |type, i|
  Campaign.create!(
    name: "#{type.titleize} 캠페인 #{i + 1}",
    campaign_type: type,
    target_segment: {
      age_group: [ "20대", "30대" ].sample,
      preferences: [ "minimal", "casual" ]
    }.to_json,
    product: Product.all.sample,
    message_template: "#{type} 상품을 확인해보세요!",
    status: [ "draft", "scheduled" ].sample,
    scheduled_at: (i.even? ? 1.hour.from_now : nil),
    target_count: rand(50..200)
  )
end

puts "✅ 생성 완료: Campaign #{Campaign.count}개"

# ==========================================
# Epic 8: 거래처 및 발주 관리 샘플 데이터
# ==========================================

puts "\n📦 Epic 8: 거래처 및 발주 관리 샘플 데이터 생성 중..."

# 1. 거래처 생성
suppliers_data = [
  {
    name: "동대문 패션타운",
    contact_person: "김동대",
    phone: "02-2234-5678",
    email: "dongdaemun@fashion.com",
    address: "서울시 중구 동대문로 123",
    payment_terms: "30일 후불",
    notes: "동대문 도매 시장 주요 거래처. 원피스, 상의류 주력"
  },
  {
    name: "남대문 의류도매",
    contact_person: "이남대",
    phone: "02-3345-6789",
    email: "namdaemun@wholesale.com",
    address: "서울시 중구 남대문로 456",
    payment_terms: "선불",
    notes: "캐주얼 의류 전문. 빠른 배송"
  },
  {
    name: "청담 럭셔리 하우스",
    contact_person: "박청담",
    phone: "02-4456-7890",
    email: "cheongdam@luxury.com",
    address: "서울시 강남구 청담동 789",
    payment_terms: "60일 후불",
    notes: "고급 브랜드 전문. 시즌별 컬렉션"
  },
  {
    name: "성수 크리에이티브",
    contact_person: "최성수",
    phone: "02-5567-8901",
    email: "seongsu@creative.com",
    address: "서울시 성동구 성수동 321",
    payment_terms: "45일 후불",
    notes: "감성 의류 및 아티스트 협업 상품"
  }
]

suppliers = suppliers_data.map do |data|
  Supplier.create!(data)
end

puts "✅ 생성 완료: Supplier #{Supplier.count}개"

# 2. 발주서 생성 (다양한 상태)
puts "\n발주서 생성 중..."

# Draft 상태 발주서 (편집 가능)
po_draft = PurchaseOrder.create!(
  supplier: suppliers[0],
  status: "draft",
  expected_delivery_date: 7.days.from_now,
  notes: "봄 시즌 신상품 발주 (초안)",
  purchase_order_items_attributes: [
    { variant: Variant.all.sample, quantity: 20, unit_price: 25000 },
    { variant: Variant.all.sample, quantity: 15, unit_price: 30000 },
    { variant: Variant.all.sample, quantity: 30, unit_price: 18000 }
  ]
)

# Submitted 상태 발주서 (거래처 확인 대기)
po_submitted = PurchaseOrder.create!(
  supplier: suppliers[1],
  status: "submitted",
  expected_delivery_date: 5.days.from_now,
  notes: "긴급 재고 보충 요청",
  purchase_order_items_attributes: [
    { variant: Variant.all.sample, quantity: 50, unit_price: 22000 },
    { variant: Variant.all.sample, quantity: 40, unit_price: 27000 }
  ]
)

# Confirmed 상태 발주서 (입고 대기)
po_confirmed = PurchaseOrder.create!(
  supplier: suppliers[2],
  status: "confirmed",
  confirmed_at: 1.day.ago,
  expected_delivery_date: 3.days.from_now,
  notes: "프리미엄 라인 정기 발주",
  purchase_order_items_attributes: [
    { variant: Variant.all.sample, quantity: 10, unit_price: 150000 },
    { variant: Variant.all.sample, quantity: 8, unit_price: 180000 },
    { variant: Variant.all.sample, quantity: 12, unit_price: 120000 }
  ]
)

# Received 상태 발주서 (입고 완료)
po_received = PurchaseOrder.create!(
  supplier: suppliers[3],
  status: "received",
  confirmed_at: 5.days.ago,
  received_at: 2.days.ago,
  expected_delivery_date: 3.days.ago,
  notes: "정기 발주 - 성수 감성 라인",
  purchase_order_items_attributes: [
    { variant: Variant.all.sample, quantity: 25, unit_price: 35000 },
    { variant: Variant.all.sample, quantity: 20, unit_price: 42000 }
  ]
)

# 추가 발주서들 (과거 이력)
3.times do |i|
  PurchaseOrder.create!(
    supplier: suppliers.sample,
    status: [ "received", "confirmed" ].sample,
    confirmed_at: rand(10..30).days.ago,
    received_at: (i.even? ? rand(5..15).days.ago : nil),
    expected_delivery_date: rand(1..10).days.from_now,
    notes: "정기 발주 ##{i + 1}",
    purchase_order_items_attributes: rand(2..4).times.map do
      {
        variant: Variant.all.sample,
        quantity: rand(10..50),
        unit_price: [ 20000, 25000, 30000, 35000, 40000 ].sample
      }
    end
  )
end

puts "✅ 생성 완료: PurchaseOrder #{PurchaseOrder.count}개"
puts "✅ 생성 완료: PurchaseOrderItem #{PurchaseOrderItem.count}개"

puts "\n🎉 Phase 2 + Epic 8 샘플 데이터 생성 완료!"
puts "=" * 50
puts "📊 통계:"
puts "  - AnonyCustomer: #{AnonyCustomer.count}명"
puts "  - Order: #{Order.count}건"
puts "  - Variant: #{Variant.count}개"
puts "  - StockLog: #{StockLog.count}건"
puts "  - Notification: #{Notification.count}건"
puts "  - Campaign: #{Campaign.count}개"
puts "  - Supplier: #{Supplier.count}개"
puts "  - PurchaseOrder: #{PurchaseOrder.count}개"
puts "  - PurchaseOrderItem: #{PurchaseOrderItem.count}개"
puts "=" * 50
