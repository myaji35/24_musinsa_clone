require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "이메일과 비밀번호가 필요하다" do
    user = User.new
    assert_not user.valid?
    assert user.errors[:email].any?
    assert user.errors[:password].any?
  end

  test "이메일 형식과 중복을 검증한다" do
    user = User.new(email: "invalid", password: "TestPassword!2026")
    assert_not user.valid?
    user.email = "  #{users(:one).email.upcase}  "
    assert_not user.valid?
    assert user.errors[:email].any?
  end

  test "이메일을 정규화하고 암호화된 비밀번호로 인증한다" do
    user = User.create!(email: "  ADMIN@example.com  ", password: "TestPassword!2026")
    assert_equal "admin@example.com", user.email
    assert_not_equal "TestPassword!2026", user.password_digest
    assert_equal user, user.authenticate("TestPassword!2026")
    assert_not user.authenticate("wrong")
  end
end
