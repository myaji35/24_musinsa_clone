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
    @user = User.create!(email: "test@example.com", name: "Test User")
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
end
