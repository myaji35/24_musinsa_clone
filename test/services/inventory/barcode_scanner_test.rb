require "test_helper"

module Inventory
  class BarcodeScannerTest < ActiveSupport::TestCase
    def setup
      @product = Product.create!(
        name: "Test Product",
        price: 50000,
        brand: "Test Brand",
        category: "Top"
      )

      @variant = @product.variants.create!(
        barcode: "SCAN-001",
        color: "Red",
        size: "L",
        stock: 15,
        min_stock: 10
      )
    end

    # 성공 케이스: 바코드 스캔
    test "should successfully scan barcode" do
      result = BarcodeScanner.call(barcode: "SCAN-001")

      assert result.success?
      assert_equal @variant.id, result.data[:variant].id
      assert_equal @product.id, result.data[:product].id
      assert_equal 15, result.data[:stock_info][:current_stock]
      assert_equal "정상", result.data[:stock_info][:status]
    end

    # 실패 케이스: 빈 바코드
    test "should fail with empty barcode" do
      result = BarcodeScanner.call(barcode: "")

      assert result.failure?
      assert_match /비어있습니다/, result.error
    end

    # 실패 케이스: nil 바코드
    test "should fail with nil barcode" do
      result = BarcodeScanner.call(barcode: nil)

      assert result.failure?
      assert_match /비어있습니다/, result.error
    end

    # 실패 케이스: 존재하지 않는 바코드
    test "should fail with non-existent barcode" do
      result = BarcodeScanner.call(barcode: "NONEXISTENT")

      assert result.failure?
      assert_match /찾을 수 없습니다/, result.error
    end

    # 재고 부족 경고
    test "should show low stock alert" do
      @variant.update(stock: 8, min_stock: 10)
      result = BarcodeScanner.call(barcode: "SCAN-001")

      assert result.success?
      assert result.data[:stock_info][:is_low_stock]
      assert_equal "재고 부족", result.data[:stock_info][:status]
      assert_equal 1, result.data[:alerts].size
      assert_equal "warning", result.data[:alerts].first[:type]
    end

    # 품절 경고
    test "should show out of stock alert" do
      @variant.update(stock: 0)
      result = BarcodeScanner.call(barcode: "SCAN-001")

      assert result.success?
      assert result.data[:stock_info][:is_out_of_stock]
      assert_equal "품절", result.data[:stock_info][:status]
      assert_equal 1, result.data[:alerts].size
      assert_equal "danger", result.data[:alerts].first[:type]
    end

    # Edge Case: 공백 포함 바코드
    test "should handle barcode with whitespace" do
      result = BarcodeScanner.call(barcode: "  SCAN-001  ")

      assert result.success?
      assert_equal @variant.id, result.data[:variant].id
    end

    # Eager Loading 확인
    test "should include product data" do
      result = BarcodeScanner.call(barcode: "SCAN-001")

      assert result.success?
      assert_not_nil result.data[:product]
      assert_equal "Test Product", result.data[:product].name
    end
  end
end
