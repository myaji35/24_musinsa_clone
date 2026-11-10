require "test_helper"

class BroadcastStockConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @variant = Variant.create!(product: products(:one), color: "방송", size: "M", stock: 50, min_stock: 0)
    @customer_ids = AnonyCustomer.pluck(:id)
    @address_ids = ShippingAddress.pluck(:id)
  end

  teardown do
    orders = Order.where(variant_id: @variant.id)
    OrderShippingRecord.where(order_id: orders.select(:id)).delete_all
    StockHold.where(variant_id: @variant.id).delete_all
    StockLog.where(variant_id: @variant.id).delete_all
    orders.delete_all
    ShippingAddress.where.not(id: @address_ids).delete_all
    AnonyCustomer.where.not(id: @customer_ids).delete_all
    @variant.delete
  end

  test "동시 홀드 500건 중 정확히 50건만 성공한다" do
    verify_concurrency do
      Inventory::StockHoldService.reserve(variant_id: @variant.id, quantity: 1)
    end
    assert_equal 50, StockHold.where(variant_id: @variant.id, status: "held").count
  end

  test "동시 주문 500건 중 정확히 50건만 성공한다" do
    address = { recipient_name: "방송고객", phone: "010-7777-9876", postal_code: "06123", address1: "서울시 테스트로 1" }
    verify_concurrency do
      Orders::Intake.call(items: [ { variant_id: @variant.id, quantity: 1 } ], address: address)
    end
    assert_equal 50, Order.where(variant_id: @variant.id).count
  end

  private

  def verify_concurrency
    queue = Queue.new
    500.times { queue << true }
    results = Queue.new
    workers = 10.times.map do
      Thread.new do
        loop do
          queue.pop(true)
          ActiveRecord::Base.connection_pool.with_connection do
            results << yield
          end
        rescue ThreadError
          break
        end
      end
    end
    workers.each(&:value)
    outcomes = 500.times.map { results.pop }
    successes = outcomes.count(&:success?)
    failures = outcomes.count(&:failure?)
    assert_equal 50, successes
    assert_equal 450, failures
    outcomes.select(&:failure?).each { |result| assert_match(/재고가 부족합니다/, Array(result.error).join) }
    assert_equal 0, @variant.reload.stock
    assert_not Variant.where(id: @variant.id).where("stock < 0").exists?
    assert_equal 50, StockLog.where(variant_id: @variant.id, log_type: "out").sum(:quantity)
    puts "동시성 #{name}: 성공 #{successes}, 재고 부족 #{failures}"
  end
end
