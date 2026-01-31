
# Clear existing data
ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = OFF")
Review.destroy_all
SnapProduct.destroy_all
Snap.destroy_all
Product.destroy_all
User.destroy_all
ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = ON")
puts "Cleared existing products"

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
    "mood" => moods.sample,
    "tpo" => tpos.sample,
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
    ai_attributes: ai_attrs.to_json,
    badges: badge_array.to_json,
    is_new: i < 5, # 처음 5개는 신상
    restocked_at: (i % 7 == 0 ? 3.days.ago : nil) # 7의 배수는 재입고
  )
end

puts "Created #{Product.count} products (Attributes by AI Model Generation)"

# Create a dummy user
user = User.first_or_create!(email: "test@example.com", name: "Musinsa Lover")

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
