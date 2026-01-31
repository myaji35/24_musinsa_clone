require "test_helper"

class ProductsHelperTest < ActionView::TestCase
  def setup
    @product = Product.new(
      name: "Test Product",
      price: 50000,
      stock: 10,
      category: "Top",
      brand: "Test Brand",
      ai_attributes: { mood: "minimal" }.to_json,
      badges: ["coupon"].to_json,
      is_new: true,
      restocked_at: nil
    )
  end

  test "product_badges returns free shipping badge for products over 30000" do
    @product.price = 50000
    badges = product_badges(@product)

    assert badges.any? { |b| b[:text] == "무료배송" }
  end

  test "product_badges returns coupon badge when product has coupon" do
    badges = product_badges(@product)

    assert badges.any? { |b| b[:text] == "쿠폰" }
  end

  test "product_badges returns new arrival badge for new products" do
    @product.is_new = true
    badges = product_badges(@product)

    assert badges.any? { |b| b[:text] == "신상" }
  end

  test "product_badges returns restocked badge for recently restocked products" do
    @product.restocked_at = 3.days.ago
    badges = product_badges(@product)

    assert badges.any? { |b| b[:text] == "재입고" }
  end

  test "discount_rate returns 30" do
    assert_equal 30, discount_rate(@product)
  end

  test "discounted_price calculates correctly" do
    @product.price = 100000
    expected = 70000 # 30% off

    assert_equal expected, discounted_price(@product)
  end

  test "mood_to_title returns correct title for known mood" do
    assert_equal "미니멀리즘의 정수", mood_to_title("minimal")
    assert_equal "편안한 일상을 위한", mood_to_title("casual")
  end

  test "mood_to_title returns mood itself for unknown mood" do
    assert_equal "unknown", mood_to_title("unknown")
  end

  test "mood_to_description returns correct description for known mood" do
    assert_equal "군더더기 없는 깔끔한 라인", mood_to_description("minimal")
  end

  test "mood_to_description returns empty string for unknown mood" do
    assert_equal "", mood_to_description("unknown")
  end
end
