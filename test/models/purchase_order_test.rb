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

  test "발주 제출 시 확인 토큰의 만료 시각을 7일 뒤로 설정한다" do
    freeze_time do
      order = purchase_orders(:one)
      assert order.submit!
      assert_equal "submitted", order.reload.status
      assert_equal 7.days.from_now, order.confirmation_token_expires_at
      assert_not order.submit!
    end
  end

  test "초안 발주는 확정할 수 없다" do
    order = purchase_orders(:one)
    assert_equal false, order.confirm!
    assert_equal "draft", order.reload.status
    assert_nil order.confirmed_at
    assert_nil order.confirmation_token_used_at
  end

  test "제출된 발주는 확정하고 토큰 사용 시각을 기록한다" do
    freeze_time do
      order = purchase_orders(:one)
      order.submit!
      assert_equal true, order.confirm!
      assert_equal "confirmed", order.reload.status
      assert_equal Time.current, order.confirmed_at
      assert_equal Time.current, order.confirmation_token_used_at
    end
  end

  test "확인 토큰은 두 번 사용할 수 없다" do
    order = purchase_orders(:one)
    order.submit!
    assert order.confirm!
    used_at = order.reload.confirmation_token_used_at
    assert_equal false, order.confirm!
    assert_equal used_at, order.reload.confirmation_token_used_at
  end

  test "제출 상태라도 사용된 확인 토큰은 거부한다" do
    order = purchase_orders(:one)
    order.submit!
    order.update!(confirmation_token_used_at: 1.hour.ago)
    assert_equal false, order.confirm!
    assert_equal "submitted", order.reload.status
    assert_nil order.confirmed_at
  end

  test "만료된 확인 토큰은 거부한다" do
    order = purchase_orders(:one)
    order.submit!
    order.update!(confirmation_token_expires_at: 1.second.ago)
    assert_equal false, order.confirm!
    assert_equal "submitted", order.reload.status
    assert_nil order.confirmed_at
    assert_nil order.confirmation_token_used_at
  end

  test "만료 시각이 없는 기존 제출 발주는 확정할 수 있다" do
    order = purchase_orders(:one)
    order.update!(status: "submitted")
    assert_nil order.confirmation_token_expires_at
    assert_equal true, order.confirm!
  end

  test "취소되거나 입고된 발주는 확정할 수 없다" do
    order = purchase_orders(:one)
    %w[cancelled received].each do |status|
      order.update!(status: status)
      assert_equal false, order.confirm!
      assert_equal status, order.reload.status
      assert_nil order.confirmed_at
      assert_nil order.confirmation_token_used_at
    end
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
  test "confirmation URL uses configured defaults and preserves explicit host override" do
    original_host = ENV.delete("APP_HOST")
    original_options = Rails.application.config.action_mailer.default_url_options
    Rails.application.config.action_mailer.default_url_options = { host: "localhost", port: 3053, protocol: "http" }
    po = purchase_orders(:one)
    assert_equal "http://localhost:3053/po/confirm/#{po.confirmation_token}", po.confirmation_url
    ENV["APP_HOST"] = "orders.example.test"
    assert_equal "http://orders.example.test/po/confirm/#{po.confirmation_token}", po.confirmation_url
    Rails.application.config.action_mailer.default_url_options = { host: "jieum.158.247.235.31.nip.io", protocol: "https" }
    assert_equal "https://orders.example.test/po/confirm/#{po.confirmation_token}", po.confirmation_url
    ENV.delete("APP_HOST")
    assert_equal "https://jieum.158.247.235.31.nip.io/po/confirm/#{po.confirmation_token}", po.confirmation_url
  ensure
    Rails.application.config.action_mailer.default_url_options = original_options
    original_host.nil? ? ENV.delete("APP_HOST") : ENV["APP_HOST"] = original_host
  end
  test "부분 입고는 잔량을 검증하고 입고마다 재고와 장부를 기록한다" do
    order = purchase_orders(:one)
    item = order.purchase_order_items.first
    order.update!(status: "confirmed")
    item.update!(quantity: 10, received_quantity: 0, unit_price: 1000)
    stock = item.variant.stock
    assert order.receive!({ item.id => 4 })
    assert_equal "partially_received", order.reload.status
    assert_equal 4, item.reload.received_quantity
    assert_equal stock + 4, item.variant.reload.stock
    assert_not order.receive!({ item.id => 7 })
    assert_equal stock + 4, item.variant.reload.stock
    assert order.receive!({ item.id => 6 })
    assert_equal "received", order.reload.status
    assert_not_nil order.received_at
    assert_equal 10, item.reload.received_quantity
    assert_equal stock + 10, item.variant.reload.stock
    assert_equal [ 4000, 6000 ], LedgerEntry.where(source: order, entry_type: "purchase").order(:id).pluck(:amount).map(&:to_i)
  end
end
