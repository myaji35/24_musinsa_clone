require "test_helper"

class UserOrdersTest < ActiveSupport::TestCase
  test "회원을 삭제하면 주문은 남고 회원 연결만 해제한다" do
    member = users(:member)
    order = orders(:one)
    order.update!(user: member)

    assert_no_difference "Order.count" do
      assert_difference "User.count", -1 do
        member.destroy!
      end
    end

    assert_nil order.reload.user_id
  end
end
