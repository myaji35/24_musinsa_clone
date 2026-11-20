require "test_helper"
require "minitest/mock"

class OrderClaims::ProcessTest < ActiveSupport::TestCase
  setup do
    @order = orders(:one)
    @actor = users(:operator)
    @claim = create_claim(@order, "cancel")
  end

  test "결제 완료 취소 승인 시 주문 취소와 재고 복원 후 완료 시 환불일을 기록한다" do
    stock = @order.variant.stock
    assert_difference -> { StockLog.where(order_id: @order.id, log_type: "in").count }, 1 do
      assert process("approve", note: "취소 승인").success?
    end
    assert_equal "cancelled", @order.reload.status
    assert_equal stock + @order.quantity, @order.variant.reload.stock
    assert_equal "approved", @claim.reload.status
    assert_equal @actor, @claim.processed_by
    assert_not_nil @claim.processed_at
    assert_nil @claim.refunded_at
    travel_to Time.current.change(usec: 0) do
      assert process("complete", note: "환불 확인").success?
      assert_equal Time.current, @claim.reload.refunded_at
      assert_equal Time.current, @claim.processed_at
    end
    assert_equal "completed", @claim.status
    assert_equal "취소 승인\n환불 확인", @claim.admin_note
  end

  test "배송된 주문의 취소 승인은 실패한다" do
    @order.update!(status: "shipped")
    result = process("approve")
    assert result.failure?
    assert_equal "이미 배송된 주문은 취소할 수 없습니다.", result.error
    assert_equal "requested", @claim.reload.status
    assert_nil @claim.processed_at
  end

  test "반품 승인 후 완료하면 주문과 재고를 복원하고 입고 기록은 중복되지 않는다" do
    @claim = create_claim(orders(:two), "return")
    order = @claim.order
    stock = order.variant.stock
    assert process("approve").success?
    assert_equal "delivered", order.reload.status
    assert_equal stock, order.variant.reload.stock
    assert_difference -> { StockLog.where(order_id: order.id, log_type: "in").count }, 1 do
      assert process("complete").success?
    end
    assert_equal "returned", order.reload.status
    assert_equal "반품 완료", order.status_label
    assert_includes Order::FINISHED_STATUSES, "returned"
    assert_equal stock + order.quantity, order.variant.reload.stock
    assert_not_nil @claim.reload.refunded_at
    assert_equal "completed", @claim.status
    assert_equal "반품 입고 #{order.order_number}", StockLog.find_by!(order_id: order.id, log_type: "in").note
    assert_no_difference "StockLog.count" do
      assert process("complete").failure?
      order.update!(status: "delivered")
      order.update!(status: "returned")
    end
    assert_equal stock + order.quantity, order.variant.reload.stock
  end

  test "교환은 승인 후 완료해도 주문 상태와 재고 및 환불일을 바꾸지 않는다" do
    @claim = create_claim(orders(:two), "exchange")
    stock = @claim.order.variant.stock
    assert process("approve").success?
    assert process("complete").success?
    assert_equal "completed", @claim.reload.status
    assert_nil @claim.refunded_at
    assert_equal "delivered", @claim.order.reload.status
    assert_equal stock, @claim.order.variant.reload.stock
  end

  test "거절 사유가 없거나 공백이면 실패하고 사유가 있으면 거절한다" do
    [ nil, "", "  " ].each do |note|
      result = process("reject", note: note)
      assert result.failure?
      assert_equal "거절 사유를 입력해 주세요.", result.error
      assert_equal "requested", @claim.reload.status
    end
    assert process("reject", note: "회수 불가").success?
    assert_equal "rejected", @claim.reload.status
    assert_equal "회수 불가", @claim.admin_note
    assert_equal @actor, @claim.processed_by
    assert_not_nil @claim.processed_at
  end

  test "잘못된 액션과 상태 전이는 실패하고 기록을 바꾸지 않는다" do
    { "requested" => %w[complete invalid], "approved" => %w[approve reject],
      "rejected" => %w[approve reject complete], "completed" => %w[approve reject complete] }.each do |status, actions|
      @claim.update!(status: status)
      actions.each do |action|
        assert process(action, note: "메모").failure?
        assert_equal status, @claim.reload.status
        assert_nil @claim.processed_at
        assert_nil @claim.admin_note
      end
    end
  end

  test "저장 예외가 나면 주문 취소와 재고 복원도 롤백한다" do
    stock = @order.variant.stock
    @claim.stub(:save!, -> { raise ActiveRecord::RecordInvalid.new(@claim) }) do
      assert_no_difference "StockLog.count" do
        assert process("approve").failure?
      end
    end
    assert_equal "paid", @order.reload.status
    assert_equal stock, @order.variant.reload.stock
    assert_equal "requested", @claim.reload.status
  end

  private

  def create_claim(order, kind)
    order.order_claims.create!(kind: kind, reason_code: "other", requester: "guest")
  end

  def process(action, note: nil)
    OrderClaims::Process.call(claim: @claim, action: action, actor: @actor, note: note)
  end
end
