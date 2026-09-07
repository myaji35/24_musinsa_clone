require "test_helper"

module Inventory
  class StockAdjusterTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    def setup
      @product = Product.create!(
        name: "Test Product",
        price: 50000,
        brand: "Test Brand",
        category: "Top"
      )

      @variant = @product.variants.create!(
        barcode: "TEST-001",
        color: "Black",
        size: "M",
        stock: 10,
        min_stock: 5
      )
    end

    # 성공 케이스: 입고
    test "should successfully stock in" do
      result = nil
      assert_difference "StockLog.count", 1 do
        result = StockAdjuster.call(
          barcode: "TEST-001",
          quantity: 5,
          stock_type: "in",
          note: "Test stock in"
        )
      end

      assert result.success?
      assert_equal 15, @variant.reload.stock
      assert_equal 15, result.data[:new_stock]
      assert_equal 15, result.data[:variant].stock
      assert_equal "입고 완료: 5개 추가 (현재 재고: 15개)", result.data[:message]
    end

    # 성공 케이스: 출고
    test "should successfully stock out" do
      result = StockAdjuster.call(
        barcode: "TEST-001",
        quantity: 3,
        stock_type: "out",
        note: "Test stock out"
      )

      assert result.success?
      assert_equal 7, @variant.reload.stock
      assert_equal "출고 완료: 3개 차감 (현재 재고: 7개)", result.data[:message]
    end

    # 실패 케이스: 바코드 없음
    test "should fail with invalid barcode" do
      result = StockAdjuster.call(
        barcode: "INVALID",
        quantity: 5,
        stock_type: "in"
      )

      assert result.failure?
      assert_match /바코드를 찾을 수 없습니다/, result.error
    end

    # 실패 케이스: 재고 부족
    test "should fail when stock insufficient" do
      result = nil
      assert_no_difference "StockLog.count" do
        result = StockAdjuster.call(
          barcode: "TEST-001",
          quantity: 20,
          stock_type: "out"
        )
      end
      assert_equal 10, @variant.reload.stock

      assert result.failure?
      assert_match /재고 부족/, result.error
    end

    # Edge Case: 음수 수량
    test "should fail with negative quantity" do
      result = StockAdjuster.call(
        barcode: "TEST-001",
        quantity: -5,
        stock_type: "in"
      )

      assert result.failure?
      assert_match /양수여야 합니다/, result.error
    end

    # Edge Case: 0 수량
    test "should fail with zero quantity" do
      result = StockAdjuster.call(
        barcode: "TEST-001",
        quantity: 0,
        stock_type: "in"
      )

      assert result.failure?
      assert_match /양수여야 합니다/, result.error
    end

    # 부작용: StockLog 생성 확인
    test "should create stock log" do
      assert_difference "StockLog.count", 1 do
        StockAdjuster.call(
          barcode: "TEST-001",
          quantity: 5,
          stock_type: "in",
          note: "Test note",
          user_name: "TestUser"
        )
      end

      log = StockLog.last
      assert_equal @variant.id, log.variant_id
      assert_equal "in", log.log_type
      assert_equal 5, log.quantity
      assert_equal "Test note", log.note
    end

    test "should store supplier and unit cost when stocking in" do
      result = StockAdjuster.call(
        barcode: "TEST-001",
        quantity: 5,
        stock_type: "in",
        supplier: "동대문 도매상",
        unit_cost: "15000"
      )

      assert result.success?
      log = @variant.stock_logs.last
      assert_equal "동대문 도매상", log.supplier
      assert_equal 15000, log.unit_cost
    end

    test "should store numeric order id when stocking out" do
      result = StockAdjuster.call(
        barcode: "TEST-001",
        quantity: 3,
        stock_type: "out",
        order_id: "123"
      )

      assert result.success?
      assert_equal 123, @variant.stock_logs.last.order_id
    end

    test "should store nil for nonnumeric order id" do
      result = StockAdjuster.call(
        barcode: "TEST-001",
        quantity: 3,
        stock_type: "out",
        order_id: "ORDER-20240131-001"
      )

      assert result.success?
      assert_nil @variant.stock_logs.last.order_id
    end

    test "should store nil for blank supplier" do
      result = StockAdjuster.call(
        barcode: "TEST-001",
        quantity: 5,
        stock_type: "in",
        supplier: ""
      )

      assert result.success?
      assert_nil @variant.stock_logs.last.supplier
    end

    # 알림: 재고 부족 시 Job 큐잉
    test "should enqueue low stock alert job when stock is low" do
      @variant.update(stock: 6, min_stock: 5)

      assert_enqueued_with(job: LowStockAlertJob, args: []) do
        StockAdjuster.call(
          barcode: "TEST-001",
          quantity: 2,
          stock_type: "out"
        )
      end
    end
  end
end
