require "test_helper"

class MemberWithdrawalTest < ActiveSupport::TestCase
  test "정의되지 않은 탈퇴 사유는 유효하지 않다" do
    withdrawal = MemberWithdrawal.new(withdrawn_at: Time.current, reason: "invalid")

    assert_not withdrawal.valid?
    assert withdrawal.errors.of_kind?(:reason, :inclusion)
  end
end
