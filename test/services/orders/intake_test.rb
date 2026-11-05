require "test_helper"

class Orders::IntakeTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  setup do
    @address = { recipient_name: "홍길동", phone: "010-7777-9876", postal_code: "06123", address1: "서울시 테스트로 1" }
    variants(:two).update!(stock: 10)
    @items = [ { variant_id: variants(:one).id, quantity: 2 }, { variant_id: variants(:two).id, quantity: 1 } ]
  end

  test "한국 오전 9시 전 주문서와 주문번호는 한국 날짜를 사용한다" do
    travel_to Time.utc(2026, 11, 1, 20, 30) do
      result = Orders::Intake.call(items: @items, address: @address)
      assert result.success?, result.errors.inspect
      assert_match /\ACHK-20261102-/, result.checkout_number
      result.orders.each do |order|
        assert_match /\ACHK-20261102-/, order.reload.checkout_number
        assert_match /\AORD-20261102-/, order.order_number
      end
    end
  end

  test "품목별 주문은 같은 주문서와 배송지를 공유하고 익명 고객에는 세 자리만 저장한다" do
    stocks = variants(:one).stock
    result = nil
    assert_difference [ "ShippingAddress.count", "AnonyCustomer.count" ], 1 do
      assert_difference "Order.count", 2 do
        result = Orders::Intake.call(items: @items, address: @address, birth_year: 1990)
      end
    end
    assert result.success?, result.errors.inspect
    assert_equal [], result.errors
    assert_match /\ACHK-\d{8}-[0-9A-F]{8}\z/, result.checkout_number
    assert_equal [ result.checkout_number ], result.orders.map(&:checkout_number).uniq
    assert_equal 1, result.orders.map(&:shipping_address_id).uniq.size
    result.orders.each do |order|
      assert_equal "pending", order.status
      assert_equal @address[:address1], order.shipping_record.address1
      assert_equal order.product.price * order.quantity, order.total_price
    end
    customer = result.orders.first.anony_customer
    assert_equal "061", customer.zip_prefix
    assert_equal "9876", customer.phone_suffix
    assert_equal 1990, customer.birth_year
    assert_nil result.orders.first.shipping_address.purge_after
    assert_not result.orders.first.shipping_address.save_consent?
    assert_equal stocks - 2, variants(:one).reload.stock
    assert_equal 9, variants(:two).reload.stock
  end

  test "기존 고객의 우편번호를 갱신하고 동의 시각을 기록한다" do
    customer = AnonyCustomer.find_or_create_by_identifier("9876", nil)
    result = Orders::Intake.call(items: @items, address: @address, save_consent: true)
    assert result.success?
    assert_equal customer.id, result.orders.first.anony_customer_id
    assert_equal "061", customer.reload.zip_prefix
    address = result.orders.first.shipping_address
    assert address.save_consent?
    assert_not_nil address.consented_at
    assert_nil address.purge_after
  end

  test "빈 품목과 잘못된 수량 및 없는 옵션은 전체 롤백한다" do
    [ [], [ @items.first, { variant_id: variants(:two).id, quantity: 0 } ],
      [ { variant_id: variants(:one).id, quantity: -1 } ],
      [ { variant_id: variants(:one).id, quantity: 1.5 } ],
      [ { variant_id: -1, quantity: 1 } ] ].each do |items|
      assert_failed_intake(items: items)
    end
  end

  test "가격 없는 상품과 잘못된 배송지는 실패한다" do
    variants(:two).product.update_column(:price, nil)
    assert_failed_intake(items: @items)
    assert_failed_intake(items: [ @items.first ], address: @address.merge(phone: "invalid"))
  end

  test "실패 시 기존 고객의 우편번호 갱신도 롤백한다" do
    customer = AnonyCustomer.find_or_create_by_identifier("9876", nil)
    customer.update!(zip_prefix: "999")
    assert_failed_intake(items: [ @items.first, { variant_id: -1, quantity: 1 } ])
    assert_equal "999", customer.reload.zip_prefix
  end


  test "판매 출고 이력과 주문을 연결하고 한 번만 차감한다" do
    result = Orders::Intake.call(items: [ @items.first ], address: @address)
    assert result.success?
    order = result.orders.first
    log = StockLog.find_by!(order_id: order.id)
    assert_equal "out", log.log_type
    assert_equal 2, log.quantity
    assert_equal "판매 출고 #{order.order_number}", log.note
    assert_equal 3, variants(:one).reload.stock
  end

  test "재고 초과와 NULL 재고는 손님용 문구로 거절한다" do
    variant = variants(:one)
    [ 1, nil ].each do |stock|
      variant.update_column(:stock, stock)
      result = Orders::Intake.call(items: [ @items.first ], address: @address)
      assert_not result.success?
      assert_equal "재고가 부족합니다: #{variant.product.name} #{variant.color}/#{variant.size} (남은 수량 #{stock.to_i}개)", result.errors.first
    end
  end

  test "같은 옵션 여러 줄 합계 초과는 출고 이력과 재고를 롤백한다" do
    assert_no_difference [ "StockLog.count", "Order.count" ] do
      result = Orders::Intake.call(items: [ @items.first.merge(quantity: 3), @items.first.merge(quantity: 3) ], address: @address)
      assert_not result.success?
    end
    assert_equal 5, variants(:one).reload.stock
  end

  test "재고 하나에 두 번 접수하면 하나만 성공한다" do
    variants(:one).update!(stock: 1)
    item = @items.first.merge(quantity: 1)
    assert Orders::Intake.call(items: [ item ], address: @address).success?
    assert_not Orders::Intake.call(items: [ item ], address: @address).success?
    assert_equal 0, variants(:one).reload.stock
  end

  test "실패한 주문은 부족 알림을 예약하지 않는다" do
    assert_no_enqueued_jobs(only: LowStockAlertJob) do
      Orders::Intake.call(items: [ @items.first, @items.first.merge(quantity: 20) ], address: @address)
    end
  end

  private

  def assert_failed_intake(items:, address: @address)
    assert_no_difference [ "Order.count", "ShippingAddress.count", "AnonyCustomer.count", "OrderShippingRecord.count" ] do
      result = Orders::Intake.call(items: items, address: address)
      assert_not result.success?
      assert_empty result.orders
      assert_nil result.checkout_number
      assert result.errors.any?
      assert_match /[가-힣]/, result.errors.first
    end
  end
end
