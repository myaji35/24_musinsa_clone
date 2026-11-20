require "test_helper"

class Orders::ClaimRequestTest < ActiveSupport::TestCase
  setup do
    @order = orders(:one)
  end

  test "미입금 취소는 즉시 완료하고 재고를 한 번 복원한다" do
    @order.update!(status: "pending")
    stock = @order.variant.reload.stock
    freeze_time do
      result = request_claim
      assert result.success?, result.error
      assert_equal "completed", result.data.status
      assert_equal Time.current, result.data.processed_at
      assert_equal "guest", result.data.requester
      assert_nil result.data.user
      assert_equal "cancelled", @order.reload.status
      assert_equal stock + @order.quantity, @order.variant.reload.stock
      assert_no_difference "StockLog.count" do
        assert request_claim.failure?
      end
    end
  end

  test "결제 완료 취소는 회원의 접수 요청으로 기록한다" do
    stock = @order.variant.reload.stock
    result = request_claim(user: users(:member))
    assert result.success?, result.error
    assert_equal "requested", result.data.status
    assert_equal "member", result.data.requester
    assert_equal users(:member), result.data.user
    assert_nil result.data.processed_at
    assert_equal "paid", @order.reload.status
    assert_equal stock, @order.variant.reload.stock
  end

  test "배송 중 취소는 거부한다" do
    @order.update!(status: "shipped")
    assert_no_difference "OrderClaim.count" do
      result = request_claim
      assert result.failure?
      assert_equal "지금은 이 요청을 할 수 없습니다.", result.error
    end
  end

  test "배송 완료 후 팔 일이 지난 반품은 거부한다" do
    @order.update!(status: "delivered")
    @order.update!(delivered_at: 8.days.ago)
    assert_no_difference "OrderClaim.count" do
      assert request_claim(kind: "return").failure?
    end
  end

  test "잘못된 사유는 즉시 취소와 재고 복원 없이 실패한다" do
    @order.update!(status: "pending")
    stock = @order.variant.reload.stock
    assert_no_difference "OrderClaim.count" do
      assert request_claim(reason_code: "invalid").failure?
    end
    assert_equal "pending", @order.reload.status
    assert_equal stock, @order.variant.reload.stock
  end

  test "처리 중 요청이 있으면 중복 접수를 거부한다" do
    assert request_claim.success?
    assert_no_difference "OrderClaim.count" do
      result = request_claim
      assert result.failure?
      assert_includes result.error, "이미 처리 중인 요청이 있습니다."
    end
  end

  private

  def request_claim(**overrides)
    Orders::ClaimRequest.call(**{ order: @order, kind: "cancel", reason_code: "other", detail: nil }.merge(overrides))
  end
end
