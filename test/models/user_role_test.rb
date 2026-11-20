require "test_helper"

class UserRoleTest < ActiveSupport::TestCase
  test "기본 역할은 일반 회원이다" do
    assert_equal "member", User.new.role
    assert_predicate User.new, :member?
  end

  test "관리자와 운영자만 직원이다" do
    assert_predicate User.new(role: :admin), :staff?
    assert_predicate User.new(role: :operator), :staff?
    assert_not User.new(role: :member).staff?
  end

  test "잘못된 역할은 유효하지 않다" do
    user = users(:other)
    user.role = :unknown

    assert_not user.valid?
    assert user.errors.of_kind?(:role, :inclusion)
  end

  test "계정이 없는 일반 회원은 관리자가 아니다" do
    user = User.new(account: nil, role: :member)

    assert_not user.admin?
  end
end
