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

  test "이름과 브랜드 검색은 LIKE 특수 문자를 글자 그대로 찾는다" do
    @product.save!
    [ "%", "_", "\\", "50%", "item_code", "path\\name" ].each do |query|
      [ :name, :brand ].each do |attribute|
        match = @product.dup
        match[attribute] = "앞#{query}뒤"
        match.save!

        assert_equal [ match.id ], Product.search_name_or_brand(query).pluck(:id)
        match.destroy!
      end
    end
    assert_includes Product.search_name_or_brand("Product"), @product
    assert_includes Product.search_name_or_brand("Brand"), @product
    assert_empty Product.search_name_or_brand("없는상품")
  end

  test "판매 가능 재고는 옵션 합계이며 선로딩 후에는 쿼리하지 않는다" do
    product = products(:one)
    product.update!(stock: 0)
    product.variants.create!(color: "White", size: "L", stock: 7)
    assert_equal 12, product.available_stock
    assert_not product.sold_out?

    product.variants.load
    assert_no_queries do
      assert_equal 12, product.available_stock
      assert_not product.sold_out?
    end

    product.variants.each { |variant| variant.update!(stock: 0) }
    product.stock = 99
    assert_equal 0, product.available_stock
    assert product.sold_out?
    product.reload
    assert_equal 0, product.available_stock
    assert product.sold_out?
  end

  test "옵션이 없으면 상품 재고를 사용하고 0과 nil은 품절이다" do
    @product.save!
    [ false, true ].each do |preloaded|
      @product.reload
      @product.variants.load if preloaded
      @product.stock = 10
      assert_equal 10, @product.available_stock
      assert_not @product.sold_out?
      [ 0, nil ].each do |stock|
        @product.stock = stock
        assert_equal 0, @product.available_stock
        assert @product.sold_out?
      end
    end
  end

  test "should be valid with all attributes" do
    assert @product.valid?
  end

  test "전 상품 무료배송이다" do
    @product.price = 30000
    assert @product.free_shipping?

    @product.price = 9900
    assert @product.free_shipping?
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

  test "카탈로그 상품은 public/catalog 에 있는 갤러리 컷만 순서대로 돌려준다" do
    @product.supplier_product_code = "JIEUM-G01"
    urls = @product.gallery_image_urls

    assert_equal "/catalog/G01/front.jpg", urls.first
    assert urls.all? { |url| Rails.public_path.join(url.delete_prefix("/")).exist? }

    @product.supplier_product_code = "JIEUM-G999"
    assert_equal [], @product.gallery_image_urls
    @product.supplier_product_code = nil
    assert_equal [], @product.gallery_image_urls
  end
end
