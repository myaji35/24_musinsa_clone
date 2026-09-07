require "test_helper"

class ProductTest < ActiveSupport::TestCase
  def setup
    @product = Product.new(
      name: "Test Product",
      price: 50000,
      stock: 10,
      category: "Top",
      brand: "Test Brand",
      ai_attributes: { "mood" => [ "minimal" ], "tpo" => [ "daily" ] },
      badges: [ "coupon" ],
      is_new: true,
      restocked_at: nil
    )
  end

  test "should be valid with all attributes" do
    assert @product.valid?
  end

  test "free_shipping? returns true for products over 30000" do
    @product.price = 30000
    assert @product.free_shipping?

    @product.price = 29999
    assert_not @product.free_shipping?
  end

  test "has_coupon? returns true when badges include coupon" do
    @product.badges = [ "coupon" ]
    assert @product.has_coupon?

    @product.badges = []
    assert_not @product.has_coupon?
  end

  test "new_arrival? returns true for products created within 7 days" do
    @product.is_new = true
    assert @product.new_arrival?

    @product.is_new = false
    @product.created_at = 5.days.ago
    assert @product.new_arrival?

    @product.created_at = 10.days.ago
    assert_not @product.new_arrival?
  end

  test "restocked? returns true for products restocked within 7 days" do
    @product.restocked_at = 3.days.ago
    assert @product.restocked?

    @product.restocked_at = 10.days.ago
    assert_not @product.restocked?

    @product.restocked_at = nil
    assert_not @product.restocked?
  end

  test "mood accessor returns correct value from ai_attributes" do
    assert_equal [ "minimal" ], @product.mood
  end

  test "tpo accessor returns correct value from ai_attributes" do
    assert_equal [ "daily" ], @product.tpo
  end

  test "badge_list returns array of badges" do
    assert_equal [ "coupon" ], @product.badge_list

    @product.badges = nil
    assert_equal [], @product.badge_list
  end

  # Edge Cases for ai_attributes parsing
  test "should handle nil ai_attributes" do
    product = Product.new(
      name: "Test",
      price: 10000,
      brand: "Brand",
      category: "Top",
      ai_attributes: nil
    )

    assert_nil product.mood
    assert_nil product.tpo
  end

  test "should handle empty string ai_attributes" do
    product = Product.new(
      name: "Test",
      price: 10000,
      brand: "Brand",
      category: "Top",
      ai_attributes: ""
    )

    assert_nil product.mood
  end

  test "should handle malformed JSON ai_attributes" do
    product = Product.new(
      name: "Test",
      price: 10000,
      brand: "Brand",
      category: "Top",
      ai_attributes: "invalid{json"
    )

    # Should not raise error, should return nil
    assert_nothing_raised do
      assert_nil product.mood
    end
  end

  test "parsed_ai_attributes should return empty hash for nil" do
    product = Product.new(ai_attributes: nil)
    assert_equal({}, product.parsed_ai_attributes)
  end

  test "parsed_ai_attributes should parse String JSON" do
    product = Product.new(ai_attributes: '{"mood":"minimal"}')
    assert_equal "minimal", product.parsed_ai_attributes["mood"]
  end
  test "저장 시 AI 속성과 배지를 단일 표현으로 정규화한다" do
    @product.ai_attributes = { mood: "minimal", tpo: "daily" }.to_json
    @product.badges = [ "coupon" ].to_json
    @product.save!
    @product.reload

    assert_kind_of Hash, @product.ai_attributes
    assert_equal [ "minimal" ], @product.mood
    assert_equal [ "daily" ], @product.tpo
    assert_equal [ "coupon" ], @product.badge_list
  end

  test "AI 속성 스코프가 해당 키의 값만 검색한다" do
    @product.ai_attributes = {
      "mood" => [ "minimal", "modern" ],
      "tpo" => [ "daily", "office" ],
      "fit_style" => "regular",
      "material_feel" => "soft"
    }
    @product.save!

    assert_includes Product.by_mood("minimal"), @product
    assert_includes Product.by_mood("modern"), @product
    assert_includes Product.by_tpo("office"), @product
    assert_includes Product.by_fit_style("regular"), @product
    assert_includes Product.by_material_feel("soft"), @product
    assert_not_includes Product.by_mood("office"), @product
    assert_not_includes Product.by_tpo("regular"), @product
    assert_not_includes Product.by_mood("%"), @product
  end

  test "잘못된 배지 표현도 배열을 반환한다" do
    [ "invalid{json", {}, 1 ].each do |value|
      @product.badges = value
      assert_equal [], @product.badge_list
    end
  end
end
