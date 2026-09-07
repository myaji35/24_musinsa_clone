require "test_helper"

class PurchaseOrderTest < ActiveSupport::TestCase
  test "상태와 중복 발주번호를 검증한다" do
    order = PurchaseOrder.new(supplier: suppliers(:one), status: "invalid", order_number: purchase_orders(:one).order_number)
    assert_not order.valid?
    assert order.errors[:status].present?
    assert order.errors[:order_number].present?
  end

  test "발주번호와 확인 토큰을 생성하고 수정 시 보존한다" do
    order = PurchaseOrder.create!(supplier: suppliers(:one))
    assert_match /\APO-\d{8}-[0-9A-F]{4}\z/, order.order_number
    assert order.confirmation_token.present?
    identifiers = [ order.order_number, order.confirmation_token ]
    order.update!(notes: "수정")
    assert_equal identifiers, [ order.reload.order_number, order.confirmation_token ]
  end

  test "신규 중첩 품목의 수량과 단가로 총액을 계산한다" do
    order = PurchaseOrder.create!(
      supplier: suppliers(:one),
      purchase_order_items_attributes: [
        { variant: variants(:one), quantity: 2, unit_price: 10000 },
        { variant: variants(:two), quantity: 3, unit_price: 20000 }
      ]
    )
    assert_equal 80000, order.reload.total_amount
    assert_equal 80000, order.purchase_order_items.sum(:subtotal)
  end

  test "대기 범위에는 제출과 확정 상태만 포함한다" do
    orders = %w[draft submitted confirmed received cancelled].map do |status|
      PurchaseOrder.create!(supplier: suppliers(:one), status: status)
    end
    assert_equal orders[1..2].map(&:id).sort, PurchaseOrder.pending.where(id: orders.map(&:id)).pluck(:id).sort
  end

  test "확정 발주 입고는 품목 수량만큼 한 번만 반영한다" do
    order = purchase_orders(:two)
    variant = variants(:two)
    assert_difference "StockLog.count", 1 do
      assert_difference "variant.reload.stock", 5 do
        assert order.receive!
      end
    end
    assert_equal "received", order.reload.status
    assert order.received_at.present?
    assert_no_difference [ "StockLog.count", "variant.reload.stock" ] do
      assert_not order.receive!
    end
  end
end
