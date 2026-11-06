require "test_helper"

class ProductSpecTest < ActiveSupport::TestCase
  setup do
    @product = products(:one)
  end

  test "카테고리의 대소문자와 공백을 무시해 템플릿을 고른다" do
    { " Outer " => "아우터", "아우터" => "아우터", "One-piece" => "원피스", "바지" => "바지", "모르는 값" => "액세서리" }.each do |category, key|
      @product.category = category
      assert_equal ProductSpec::MEASUREMENT_TEMPLATES[key], @product.product_spec.measurement_items
    end
  end

  test "사이즈 정렬과 현재 옵션만 표와 누락 계산에 사용한다" do
    %w[특수2 XL S 특수1].each { |size| @product.variants.create!(color: "검정", size: size, stock: 0) }
    assert_equal %w[S M XL 특수2 특수1], @product.product_spec.sizes
    @product.spec = { "measurements" => { "삭제됨" => { "총장" => "50" } } }
    assert_not @product.product_spec.measurements?
    assert_not @product.product_spec.missing_items.any? { |item| item.include?("삭제됨") }
    assert @product.save
    assert_equal "50", @product.reload.spec.dig("measurements", "삭제됨", "총장")
  end

  test "실측과 무게 경계값을 검증하고 상품 오류에 올린다" do
    { "0" => false, "0.1" => true, "300" => true, "300.1" => false, "52.5" => true, "52cm" => false, "-1" => false, "abc" => false, "" => true }.each do |value, expected|
      @product.spec = { "measurements" => { "M" => { "총장" => value } } }
      assert_equal expected, @product.valid?, value
      assert_includes @product.errors.full_messages.join, "M 사이즈 총장은" unless expected
    end
    %w[0 20001 1.1 abc].each do |weight|
      @product.spec = { "weight_g" => weight }
      assert_not @product.valid?
    end
    [ "", "1", "20000" ].each do |weight|
      @product.spec = { "weight_g" => weight }
      assert @product.valid?
    end
  end

  test "오류 문구의 조사는 항목의 받침에 따라 선택한다" do
    @product.spec = {
      "measurements" => { "M" => { "어깨너비" => "0", "총장" => "0", "width" => "0" } },
      "material" => { "충전재" => "가" * 101 },
      "fit" => { "안감 유무" => "임의" }
    }

    assert_not @product.valid?
    messages = @product.errors.full_messages
    assert_includes messages, "M 사이즈 어깨너비는 0보다 크고 300 이하인 숫자(cm)로 입력해 주세요"
    assert_includes messages, "M 사이즈 총장은 0보다 크고 300 이하인 숫자(cm)로 입력해 주세요"
    assert_includes messages, "M 사이즈 width은(는) 0보다 크고 300 이하인 숫자(cm)로 입력해 주세요"
    assert_includes messages, "소재 충전재는 100자 이하로 입력해 주세요"
    assert_includes messages, "안감 유무는 정해진 보기에서 선택해 주세요"
  end

  test "핏 보기와 계절 복수 선택 및 텍스트 길이를 검증한다" do
    @product.spec = { "fit" => { "핏" => "임의" } }
    assert_not @product.valid?
    @product.spec = { "fit" => { "핏" => [ "슬림", "오버" ] } }
    assert_not @product.valid?
    @product.spec = { "fit" => { "계절" => %w[봄 여름] } }
    assert @product.valid?
    @product.spec = { "fit" => { "계절" => %w[봄 장마] } }
    assert_not @product.valid?
    @product.spec = { "material" => { "겉감" => "가" * 101 }, "note" => "가" * 301 }
    assert_not @product.valid?
    assert_equal 2, @product.errors.count
  end

  test "필수 누락과 완성도 및 TODO를 계산한다" do
    spec = @product.product_spec
    assert_equal 0, spec.completion_rate
    assert_includes spec.missing_items, "실측 · M 총장"
    assert_includes spec.missing_items, "소재 · 겉감"
    assert_includes spec.missing_items, "핏 · 두께감"
    @product.spec = {
      "measurements" => { "M" => spec.measurement_items.index_with { "50" } },
      "material" => { "겉감" => "관리자 입력" },
      "fit" => ProductSpec::FIT_OPTIONS.transform_values(&:first)
    }
    assert_equal 100, spec.completion_rate
    assert spec.complete?
    @product.spec["material"]["겉감"] = "TODO: 확인"
    assert_includes spec.missing_items, "소재 · 겉감"
    @product.spec = { "measurements" => { "M" => { "총장" => "TODO: 확인" } }, "fit" => { "계절" => [ "TODO: 확인" ] } }
    assert @product.valid?
    assert_equal 0, spec.completion_rate
    assert_not spec.measurements?
    empty_product = Product.new(category: "상의")
    assert_equal 0, empty_product.product_spec.completion_rate
  end

  test "고시는 빈 칸만 채우고 기존 값을 보존한다" do
    @product.update!(spec: { "material" => { "겉감" => "면", "안감" => "폴리에스터", "충전재" => "솜" } })
    assert_equal "겉감: 면, 안감: 폴리에스터, 충전재: 솜", @product.info_notice["소재"]
    assert_equal "black", @product.info_notice["색상"]
    assert_equal "M", @product.info_notice["치수"]
    existing = @product.info_notice.dup
    @product.update!(spec: { "material" => { "겉감" => "울" } })
    assert_equal existing, @product.reload.info_notice
    @product.update!(info_notice: {}, spec: { "material" => { "겉감" => "울" } }, name: "새 이름")
    @product.update!(spec: { "material" => { "겉감" => "면" } })
    assert_equal "면", @product.info_notice["소재"]
  end
end
