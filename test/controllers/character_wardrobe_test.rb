require "test_helper"

class CharacterWardrobeTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:one)
    @character = Character.create!(name: "강유나", handle: "runway-model", status: "planned",
      age_band: 20, height_cm: 163, top_size: "55", bottom_size: "26", shoe_mm: 235, body_type: "보통")
  end

  test "공개 상품 상세 안내문 배지 착용 정보 및 옷장 링크" do
    @product.update!(worn_character: @character, worn_size: "M")
    get product_path(@product)
    assert_response :success
    assert_includes response.body, "착용 모델은 AI 가상 인물(강유나)이며, 의류는 실제 판매 상품입니다."
    assert_select "span", text: "가상 인물"
    assert_select "[data-worn-character]", text: "강유나 163cm · 상의 55 / M 착용"
    assert_select "a[href=?]", character_path(@character.handle), text: "강유나"
    assert_select "video", count: 0
  end

  test "빈 착용 정보는 생략한다" do
    @character.update!(height_cm: nil, top_size: nil)
    @product.update!(worn_character: @character)
    get product_path(@product)
    assert_select "[data-worn-character]", text: "강유나"
  end

  test "캐릭터 없는 기존 상품에는 안내와 배지가 없다" do
    get product_path(@product)
    assert_response :success
    assert_select "[data-worn-character]", count: 0
    assert_select "video", count: 0
    assert_not_includes response.body, "가상 인물"
  end

  test "영상은 갤러리 첫 화면에 속성과 포스터 및 배지와 표시한다" do
    @product.update!(image_url: "/images/products/product_1.svg")
    @product.runway_video.attach(io: File.open(file_fixture("runway.mp4")), filename: "runway.mp4", content_type: "video/mp4", identify: false)
    get product_path(@product)
    assert_response :success
    assert_select "video[muted][autoplay][loop][playsinline][controls][poster]", count: 1
    assert_select "video + span", text: "가상 인물"
  end

  test "관리자가 착용 정보와 영상을 저장한다" do
    sign_in
    get edit_product_path(@product)
    assert_select "select[name='product[worn_character_id]'] option", text: "강유나(20대)"
    assert_select "input[type=file][name='product[runway_video]'][accept='video/mp4,video/webm,video/quicktime']"
    patch product_path(@product), params: { product: { worn_character_id: @character.id, worn_size: "M",
      runway_video: fixture_file_upload("runway.mp4", "video/mp4") } }
    assert_redirected_to product_path(@product)
    assert_equal @character, @product.reload.worn_character
    assert_equal "M", @product.worn_size
    assert @product.runway_video.attached?
  end

  test "공개 옷장에 인물 정보와 착용 상품 카드를 표시한다" do
    @product.update!(worn_character: @character)
    get character_path(@character.handle)
    assert_response :success
    assert_includes response.body, "AI로 만든 가상 인물입니다 · 실존 인물이 아닙니다"
    assert_select "span", text: "가상 인물"
    %w[163cm 55 26 235mm 보통].each { |value| assert_select "dd", text: value }
    assert_select "a[href=?]", product_path(@product)
  end

  test "공개 옷장의 빈 상태와 없는 handle" do
    get character_path(@character.handle)
    assert_response :success
    assert_includes response.body, "아직 입은 상품이 없어요"
    get character_path("missing-character")
    assert_response :not_found
  end

  test "완료된 주 캐릭터와 대안 캐릭터 추천을 중복 없이 표시한다" do
    ProductAnalysis.create!(product: @product, character: @character, status: "done")
    ProductAnalysis.create!(product: @product, alt_character: @character, status: "done")
    alternative = products(:two)
    ProductAnalysis.create!(product: alternative, alt_character: @character, status: "done")
    excluded = @product.dup
    excluded.update!(name: "분석 중인 상품")
    ProductAnalysis.create!(product: excluded, character: @character, status: "running")

    get character_path(@character.handle)
    assert_response :success
    assert_select "section[aria-labelledby=recommended-products-title]" do |section|
      assert_select "h2", text: "강유나에게 추천하는 코디"
      assert_select "a[href=?]", product_path(@product), count: 1
      assert_select "a[href=?]", product_path(alternative), count: 1
      assert_select "a[href=?]", product_path(excluded), count: 0
      assert_not_includes section.text, "착용"
      assert_includes section.text, "직접 입은 상품은 아니에요"
    end
    assert_not_includes response.body, "아직 입은 상품이 없어요"

    @product.update!(worn_character: @character)
    get character_path(@character.handle)
    assert_select "h2", text: "착용 상품"
    assert_select "#recommended-products-title", count: 0
    assert_select "a[href=?]", product_path(alternative), count: 0
  end

  test "추천 상품은 최신순 최대 8개이며 카드 연관을 미리 읽는다" do
    created = 9.times.map do |index|
      product = @product.dup
      product.update!(name: "추천 상품 #{index}", created_at: index.days.ago)
      ProductAnalysis.create!(product: product, character: @character, status: "done")
      product
    end
    recommendations = @character.recommended_products.strict_loading.to_a
    assert_equal created.first(8).map(&:id), recommendations.map(&:id)
    recommendations.each do |product|
      assert product.association(:reviews).loaded?
      assert product.association(:image_attachment).loaded?
      product.reviews.length
      product.image.attached?
    end
  end

  test "상품이 없으면 같은 스타일의 다른 옷장을 최대 4명 안내한다" do
    @character.update!(style_axis: "minimal")
    peers = 5.times.map do |index|
      Character.create!(name: "비슷한 인물 #{index}", handle: "similar-#{index}", style_axis: "minimal", status: "planned")
    end
    other = Character.create!(name: "다른 스타일", handle: "other-style", style_axis: "casual", status: "planned")
    get character_path(@character.handle)
    assert_select "h2", text: "비슷한 스타일의 다른 옷장"
    peers.first(4).each do |peer|
      assert_select "a[href=?]", character_path(peer.handle), text: "#{peer.name}의 옷장"
    end
    [ @character, peers.last, other ].each do |excluded|
      assert_select "a[href=?]", character_path(excluded.handle), count: 0
    end
    @character.update!(style_axis: nil)
    get character_path(@character.handle)
    assert_includes response.body, "아직 입은 상품이 없어요"
    assert_select "h2", text: "비슷한 스타일의 다른 옷장", count: 0
  end

  test "실제 아바타 사진과 런웨이는 자동 재생 없이 표시한다" do
    @character.update!(handle: "KangUNA")
    get character_path(@character.handle)
    assert_response :success
    assert_select "img[alt=?]", "강유나 (AI 가상 인물)", count: 1
    assert_select "video[preload=none][controls][muted][playsinline][poster='/intro/runway/KangUNA-poster.jpg'][src='/intro/runway/KangUNA.mp4']", count: 1
    assert_select "video[autoplay]", count: 0

    get character_path("runway-model-missing")
    assert_response :not_found
    @character.update!(handle: "runway-model")
    get character_path(@character.handle)
    assert_select "img[alt=?]", "강유나 (AI 가상 인물)", count: 0
    assert_select "video", count: 0
  end
end
