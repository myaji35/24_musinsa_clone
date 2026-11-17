require "test_helper"

class OrderClaimTest < ActiveSupport::TestCase
  setup do
    @order = orders(:one)
  end

  test "종류 상태 사유 요청자와 상세 길이를 검증한다" do
    claim = @order.order_claims.build(kind: "cancel", reason_code: "other", requester: "guest")
    assert claim.valid?
    assert_equal "취소", claim.kind_label
    assert_equal "접수", claim.status_label
    assert_equal "기타", claim.reason_label
    assert_equal 3, OrderClaim::RETENTION_YEARS
    %i[kind status reason_code requester].each do |attribute|
      original = claim.public_send(attribute)
      [ nil, "invalid" ].each do |value|
        claim.public_send("#{attribute}=", value)
        assert_not claim.valid?
        assert claim.errors[attribute].present?
      end
      claim.public_send("#{attribute}=", original)
    end
    claim.detail = "가" * 500
    assert claim.valid?
    claim.detail += "나"
    assert_not claim.valid?
  end

  test "접수 또는 승인 요청이 있으면 같은 주문의 중복 요청을 거부한다" do
    %w[requested approved].each do |status|
      existing = @order.order_claims.create!(kind: "cancel", status: status, reason_code: "other", requester: "guest")
      assert existing.valid?
      duplicate = @order.order_claims.build(kind: "cancel", reason_code: "size", requester: "member")
      assert_not duplicate.valid?
      assert_includes duplicate.errors[:base], "이미 처리 중인 요청이 있습니다."
      assert_equal existing, @order.active_claim
      existing.destroy!
    end
  end

  test "완료와 거절 요청은 재요청을 막지 않고 주문 삭제는 제한한다" do
    %w[completed rejected].each do |status|
      @order.order_claims.create!(kind: "cancel", status: status, reason_code: "other", requester: "guest")
    end
    assert_nil @order.active_claim
    assert @order.order_claims.build(kind: "cancel", reason_code: "other", requester: "guest").valid?
    assert_not @order.destroy
  end

  test "요청자와 처리자 삭제 시 연결만 해제하고 기록을 보관한다" do
    claim = @order.order_claims.create!(kind: "cancel", reason_code: "other", requester: "member",
      user: users(:member), processed_by: users(:other))
    User.where(id: [ users(:member).id, users(:other).id ]).delete_all
    assert_nil claim.reload.user_id
    assert_nil claim.processed_by_user_id
    assert_equal "member", claim.requester
  end
end
