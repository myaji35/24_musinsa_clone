
# 운영 DB 보호: 이 시드는 전체 삭제 후 재생성한다. 데이터가 있는 운영 환경에서는 실행을 막는다.
if Rails.env.production? && Product.exists? && ENV["ALLOW_PRODUCTION_RESEED"] != "1"
  abort "운영 DB에 데이터가 있어 시드를 중단합니다(전체 삭제 위험). 의도한 경우에만 ALLOW_PRODUCTION_RESEED=1"
end

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

# 상품 카탈로그: 2026-10-20 받은 의류 33장을 30개 상품으로 묶음(db/seeds/jieum_catalog.yml)
Rake::Task["characters:sync"].invoke # worn_character 연결에 필요
catalog = YAML.load_file(Rails.root.join("db/seeds/jieum_catalog.yml"))
fit_styles = [ "regular", "oversized", "loose" ]
catalog.each_with_index do |item, i|
  character = Character.find_by(handle: item["model"])
  product = Product.create!(
    name: item["name"],
    description: "#{item["colors"].join(" · ")} #{item["name"]}. 착용 이미지는 AI 가상 인물이 입은 모습이며, 실제 색상·핏은 실물 사진과 실측 사이즈를 확인해 주세요.",
    price: item["price"],
    stock: 0,
    category: item["category"],
    brand: "JIEUM",
    gender: "Women",
    views_count: rand(100..5000),
    sales_count: rand(10..500),
    image_url: "/catalog/#{item["id"]}/front.jpg",
    supplier_product_code: "JIEUM-#{item["id"]}",
    worn_character: character,
    worn_size: character&.top_size&.first,
    ai_attributes: { "mood" => [ item["mood"] ], "tpo" => [ "daily" ], "fit_style" => fit_styles[i % 3], "material_feel" => "warm" },
    badges: (i % 4 == 0 ? [ "coupon" ] : []),
    is_new: true
  )
  item["colors"].each do |color|
    [ "S", "M", "L" ].each do |size|
      variant = Variant.create!(product: product, color: color, size: size, stock: rand(0..30), min_stock: 10)
      StockLog.create!(variant: variant, log_type: "in", quantity: rand(10..50), supplier: "카카오톡 거래처",
                       unit_cost: product.price * 0.6, note: "초기 입고")
    end
  end
end
puts "Created #{Product.count} products (Attributes by AI Model Generation)"

# 개발용 관리자 계정 (샘플 스냅 작성자)
user = User.create!(email: "admin@jieun.test", name: "관리자", password: "JieunDev!2026")

# 리뷰는 만들지 않는다 — 시드 리뷰가 실제 후기처럼 보이는 문제(대표님 결정 2026-10-22로 운영에서도 삭제)

# 샘플 스냅
Product.order("RANDOM()").limit(10).each do |product|
  Snap.create!(
    user: user,
    content: "#{product.name} 데일리 코디 #{[ '#데일리룩', '#출근룩', '#데이트룩' ].sample} #OOTD",
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
