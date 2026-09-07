require "test_helper"

class VariantTest < ActiveSupport::TestCase
  test "재고 없이 생성하면 재고를 0으로 저장한다" do
    variant = Variant.create!(product: products(:one), color: "Navy", size: "S")
    assert_equal 0, variant.reload.stock
  end

  test "재고가 nil인 상태로 생성하면 재고를 0으로 저장한다" do
    variant = Variant.create!(product: products(:one), color: "Navy", size: "S", stock: nil)
    assert_equal 0, variant.reload.stock
  end

  test "기존 재고를 nil로 변경할 수 없다" do
    variant = variants(:one)
    assert_not variant.update(stock: nil)
    assert variant.errors[:stock].present?
  end

  test "색상과 사이즈는 필수이고 재고는 음수가 될 수 없다" do
    variant = Variant.new(product: products(:one), stock: -1, min_stock: -1)
    assert_not variant.valid?
    %i[color size stock min_stock].each { |attribute| assert variant.errors[attribute].present? }
  end

  test "바코드와 SKU를 자동 생성하고 중복 바코드에는 번호를 붙인다" do
    attributes = { product: products(:one), color: "Navy Blue", size: "s", stock: 0 }
    first = Variant.create!(attributes)
    second = Variant.create!(attributes)
    assert_equal "#{products(:one).id}-navy-blue-S", first.barcode
    assert_equal first.barcode, first.sku_code
    assert_equal "#{first.barcode}-1", second.barcode
  end

  test "명시한 바코드를 보존하고 중복을 거부한다" do
    variant = Variant.new(product: products(:one), color: "Red", size: "S", barcode: variants(:one).barcode)
    assert_not variant.valid?
    assert variant.errors[:barcode].present?
    variant.barcode = "CUSTOM-RED-S"
    variant.save!
    assert_equal "CUSTOM-RED-S", variant.reload.barcode
  end

  test "재고 부족과 품절의 경계값을 판별한다" do
    variant = variants(:one)
    variant.assign_attributes(stock: 5, min_stock: 5)
    assert variant.low_stock?
    assert_not variant.out_of_stock?
    variant.stock = 6
    assert_not variant.low_stock?
    variant.stock = 0
    assert variant.out_of_stock?
    variant.stock = nil
    assert variant.out_of_stock?
    assert_not variant.low_stock?
  end
end
