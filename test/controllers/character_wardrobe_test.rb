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
    assert_includes response.body, "이 상품의 착용 이미지·영상은 AI로 만든 가상 인물(강유나)입니다."
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
end
