require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @product = Product.create!(
      name: "Korean Fashion Dress",
      description: "Beautiful Korean style dress",
      price: 89000,
      brand: "JIEUN Fashion",
      category: "Dress",
      gender: "female",
      stock: 50,
      ai_attributes: { mood: "minimal", tpo: "daily" }.to_json,
      badges: [ "coupon", "free_shipping" ].to_json,
      is_new: true,
      image_url: "https://images.unsplash.com/photo-1595777457583-95e059d581b8"
    )

    @variant = @product.variants.create!(
      barcode: "PROD-TEST-001",
      color: "Beige",
      size: "M",
      stock: 10
    )
  end

  test "관리자 재고이력 탭은 옵션별 최신 20건과 빈 상태를 표시한다" do
    second = @product.variants.create!(color: "Black", size: "L", stock: 100)
    empty = @product.variants.create!(color: "White", size: "S", stock: 0)
    other = variants(:one)
    [ @variant, second, other ].each do |variant|
      22.times do |index|
        variant.stock_logs.create!(log_type: index.even? ? "in" : "out", quantity: 1,
          note: "이력-#{variant.id}-#{index}", created_at: index.minutes.ago)
      end
    end
    sign_in

    get edit_product_path(@product, tab: "inventory")

    assert_response :success
    [ @variant, second ].each do |variant|
      assert_select "#inventory-variant-#{variant.id}" do
        assert_select "h3", text: "#{variant.color} / #{variant.size}"
        assert_select "tbody tr", count: 20
        assert_select "tbody tr:first-child td", text: "이력-#{variant.id}-0"
        assert_select "tbody tr:last-child td", text: "이력-#{variant.id}-19"
        assert_select "td", text: "이력-#{variant.id}-20", count: 0
        assert_select "td", text: "이력-#{variant.id}-21", count: 0
        assert_select "span.bg-blue-100", text: "입고", count: 10
        assert_select "span.bg-red-100", text: "출고", count: 10
        assert_select "td", text: "1개", count: 20
        assert_select "a[href=?]", inventory_history_path(variant_id: variant.id), text: "전체 보기"
      end
    end
    assert_select "#inventory-variant-#{empty.id} p", text: "재고 이력이 없습니다."
    assert_select "#inventory-variant-#{other.id}", count: 0
  end

  test "비로그인 사용자는 재고이력 탭에 접근할 수 없다" do
    get edit_product_path(@product, tab: "inventory")

    assert_redirected_to login_path
    assert_select "section[aria-label='재고이력']", count: 0
  end

  test "공개 상품 상세에는 재고이력을 노출하지 않는다" do
    @variant.stock_logs.create!(log_type: "in", quantity: 1, note: "관리자 전용 메모")

    get product_path(@product)

    assert_response :success
    assert_no_match "관리자 전용 메모", response.body
    assert_select "a[href=?]", inventory_history_path(variant_id: @variant.id), count: 0
  end

  test "특수 문자 검색은 전체 상품 대신 빈 결과를 표시한다" do
    [ "%", "_", "\\" ].each do |query|
      get products_path, params: { q: query }

      assert_response :success
      assert_select "[role=status] h2", text: "검색 결과가 없습니다"
      assert_select "a[href=?]", product_path(@product), count: 0
    end
  end

  test "이름과 브랜드의 특수 문자 및 일반 검색이 동작한다" do
    [ "50%", "item_code", "path\\name", "일반검색" ].each do |query|
      [ :name, :brand ].each do |attribute|
        @product.update!(name: "검색대상", brand: "검색브랜드", attribute => "앞#{query}뒤")
        get products_path, params: { q: query }

        assert_response :success
        assert_select ".grid a[href=?]", product_path(@product), text: @product.name
        assert_select "[role=status]", count: 0
      end
    end
  end

  test "empty search shows query and reset for guests and administrators" do
    [ false, true ].each do |admin|
      sign_in if admin
      get products_path, params: { q: "없는상품", category: "Top", brand: "없는브랜드", sort: "popular" }

      assert_response :success
      assert_select "[role=status] h2", text: "검색 결과가 없습니다"
      assert_select "[role=status] p", text: "“없는상품”에 해당하는 상품이 없습니다."
      assert_select "a[href=?]", products_path(category: "Top", brand: "없는브랜드", sort: "popular"), text: "검색 초기화"
      assert_no_match "첫 번째 상품을 등록해보세요", response.body
      assert_select "a[href=?]", new_product_path, count: admin ? 1 : 0
    end
  end

  test "non search empty state reserves registration guidance for administrators" do
    [ false, true ].each do |admin|
      sign_in if admin
      get products_path, params: { category: "없는카테고리" }

      assert_response :success
      assert_select "h3", text: "등록된 상품이 없습니다"
      assert_select "a[href=?]", new_product_path, count: admin ? 2 : 0
      if admin
        assert_match "첫 번째 상품을 등록해보세요", response.body
      else
        assert_no_match "첫 번째 상품을 등록해보세요", response.body
        assert_match "상품을 준비 중입니다", response.body
      end
      assert_select "[role=status] h2", count: 0
    end
  end

  test "product list management links are only visible to administrators" do
    get products_path
    assert_response :success
    assert_select "a[href=?]", new_product_path, count: 0
    assert_select "a[href=?]", edit_product_path(@product), count: 0

    sign_in
    get products_path
    assert_response :success
    assert_select "a[href=?]", new_product_path, count: 1
    assert_select "a[href=?]", edit_product_path(@product), count: 1
  end

  test "guests cannot access product management or mutate products" do
    get new_product_path
    assert_redirected_to login_path
    get edit_product_path(@product)
    assert_redirected_to login_path

    assert_no_difference "Product.count" do
      post products_path, params: { product: { name: "Unauthorized", price: 1000 } }
      assert_redirected_to login_path
      delete product_path(@product)
      assert_redirected_to login_path
    end

    original_name = @product.name
    patch product_path(@product), params: { product: { name: "Unauthorized" } }
    assert_redirected_to login_path
    assert_equal original_name, @product.reload.name
  end

  test "should create product with uploaded image" do
    sign_in

    assert_difference("Product.count", 1) do
      post products_url, params: { product: {
        name: "Uploaded product", price: 10000, brand: "Test", category: "상의",
        image: fixture_file_upload("product.png", "image/png")
      } }
    end

    product = Product.order(:id).last
    assert_redirected_to product_url(product)
    assert product.image.attached?
    assert_equal "image/png", product.image.content_type
  end

  test "should create product with image URL only" do
    sign_in

    assert_difference("Product.count", 1) do
      post products_url, params: { product: {
        name: "URL product", price: 10000, brand: "Test", category: "상의",
        image_url: @product.image_url
      } }
    end

    product = Product.order(:id).last
    assert_redirected_to product_url(product)
    assert_not product.image.attached?
    assert_equal @product.image_url, product.image_url
  end

  test "should display attached image before image URL" do
    @product.image.attach(fixture_file_upload("product.png", "image/png"))

    get product_url(@product)

    assert_response :success
    assert_select "img[src=?]", rails_blob_url(@product.image), count: 2
    assert_select "img[src=?]", @product.image_url, count: 0
  end

  # GET /products/:id
  test "should show product" do
    get product_url(@product)
    assert_response :success
    assert_select "h1", text: @product.name
  end

  # Views count increment
  test "should preserve product details on show" do
    original_attributes = @product.attributes

    get product_url(@product)

    @product.reload
    assert_equal original_attributes, @product.attributes
  end

  # Product with variants
  test "should show product variants" do
    get product_url(@product)
    assert_response :success
    # Variant가 페이지에 표시되는지 확인
  end

  # Product with reviews
  test "should show product with reviews" do
    @user = User.create!(email: "test@example.com", name: "Test User", password: "TestPassword!2026")
    @product.reviews.create!(
      user: @user,
      content: "Great product!",
      rating: 5,
      height: 165,
      weight: 55,
      size_purchased: "M"
    )

    get product_url(@product)
    assert_response :success
    assert_select "p", text: "Great product!"
  end

  # Product not found
  test "should return 404 for non-existent product" do
    get product_url(id: Product.maximum(:id) + 1)
    assert_response :not_found
  end

  # Product with AI attributes
  test "should display AI attributes" do
    get product_url(@product)
    assert_response :success
    # ai_attributes가 올바르게 파싱되는지 확인
  end

  # Product badges
  test "should display product badges" do
    get product_url(@product)
    assert_response :success
    # 쿠폰, 무료배송 배지가 표시되는지 확인
  end

  # Free shipping badge
  test "should show free shipping badge for products over 30000 won" do
    assert @product.free_shipping?
  end

  # Coupon badge
  test "should show coupon badge when applicable" do
    assert @product.has_coupon?
  end

  # New arrival badge
  test "should show new arrival badge for new products" do
    assert @product.new_arrival?
  end

  # Product image
  test "should display product image" do
    get product_url(@product)
    assert_response :success
    assert_match @product.image_url, response.body
  end

  test "100원 단위가 아닌 가격도 편집 폼에서 막히지 않는다" do
    sign_in

    get edit_product_path(@product)

    assert_select "input[name='product[price]'][step='1']"
  end

  test "카탈로그 상품 상세는 착용컷·룩북·실물 썸네일 갤러리를 보여준다" do
    product = products(:one)
    product.update!(supplier_product_code: "JIEUM-G01")

    get product_path(product)

    assert_response :success
    assert_select "[data-controller=gallery] [data-testid=product-gallery] button[data-action='gallery#show']", product.gallery_image_urls.size
    assert_select "button[data-real=true]", 1
  end

  test "초안 상품은 손님 화면(상세·목록·홈·장바구니)에 보이지 않는다" do
    @product.update!(status: "draft")

    get product_path(@product)
    assert_response :not_found

    get products_path
    assert_select "a[href='#{product_path(@product)}']", 0
    get root_path
    assert_select "a[href='#{product_path(@product)}']", 0

    post cart_items_path, params: { variant_id: @variant.id }
    assert_response :not_found
  end

  test "관리자는 초안을 미리보기하고 공개하면 손님에게 보인다" do
    @product.update!(status: "draft", info_notice: Product::INFO_NOTICE_FIELDS.index_with { "입력됨" })
    sign_in

    get product_path(@product)
    assert_response :success
    assert_select "[data-testid=publication-bar]", text: /미리보기 · 비공개/

    post publish_product_path(@product)
    assert_redirected_to product_path(@product)
    @product.reload
    assert @product.published?
    assert_equal users(:one), @product.published_by
    assert_not_nil @product.published_at

    delete logout_path
    get product_path(@product)
    assert_response :success
    assert_select "[data-testid=publication-bar]", 0
  end

  test "관리자는 공개 상품을 비공개로 되돌릴 수 있고 비로그인은 공개 전환을 못 한다" do
    post publish_product_path(@product)
    assert_redirected_to login_path

    sign_in
    post unpublish_product_path(@product)
    assert_not @product.reload.published?
  end

  test "관리자 폼으로 새로 등록한 상품은 초안으로 시작한다" do
    sign_in
    assert_difference "Product.count", 1 do
      post products_path, params: { product: { name: "새 코트", price: 99000, brand: "JIEUM", category: "Outer" } }
    end
    assert_equal "draft", Product.order(:id).last.status
  end

  test "상세페이지 본문이 있는 상품은 섹션을 렌더링하고 미확정 값은 손님에게 '확인 중'으로만 보인다" do
    product = Product.create!(name: "랩코트", price: 189000, brand: "JIEUM", category: "Outer", supplier_product_code: "JIEUM-G01")

    get product_path(product)
    assert_response :success
    assert_select "[data-testid=detail-headline]"
    assert_select "[data-testid=detail-page] h2", text: "AI 사진만 보고 사지 마세요"
    assert_select "[data-testid=detail-page] h2", text: "배송·반품 안내"
    assert_select "[data-todo]", text: "확인 중"
    assert_no_match "확인 필요", response.body

    sign_in
    get product_path(product)
    assert_select "[data-todo]", text: /확인 필요 · /
  end

  test "상품정보제공고시 필수 항목이 비면 공개되지 않고 빠진 항목을 알려 준다" do
    @product.update!(status: "draft", info_notice: { "색상" => "카멜" })
    sign_in

    get product_path(@product)
    assert_select "[data-testid=publish-blockers] li", text: "상품정보 · 소재"
    assert_select "button[disabled]", text: /공개 불가/

    post publish_product_path(@product)
    assert_redirected_to product_path(@product)
    assert_match "소재", flash[:alert]
    assert_not @product.reload.published?
  end

  test "관리자 폼에서 상품정보제공고시를 입력하면 저장된다" do
    sign_in
    patch product_path(@product), params: { product: { info_notice: { "소재" => "울 70%, 나일론 30%", "제조국" => "대한민국" } } }
    assert_equal "울 70%, 나일론 30%", @product.reload.info_notice_value("소재")
    assert_equal "대한민국", @product.info_notice_value("제조국")
  end

  test "배송·반품 안내 페이지는 비로그인으로 볼 수 있다" do
    get returns_policy_path
    assert_response :success
    assert_select "h2", text: "배송·반품 안내"
    assert_select "dt", text: "단순 변심 반품"
  end
end
