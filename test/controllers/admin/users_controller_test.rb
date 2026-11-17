require "test_helper"
require "minitest/mock"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "관리자는 사용자 목록과 역할 변경 양식을 본다" do
    sign_in
    get admin_users_path
    assert_response :success
    User.find_each do |user|
      assert_select "td", text: user.email
      assert_select "table form[action=?]", admin_user_path(user) do
        assert_select "select[name='user[role]'] option", count: 3
        assert_select "input[value='변경']"
      end
      assert_select "ul form[action=?]", admin_user_path(user) do
        assert_select "select[name='user[role]'] option", count: 3
      end
    end
    assert_select "td", text: "몰"
    assert_select "td", text: "관리자"
  end

  test "관리자는 회원을 운영자로 변경한다" do
    sign_in
    patch admin_user_path(users(:member)), params: { user: { role: "operator" } }
    assert_redirected_to admin_users_path
    assert_equal "역할을 변경했습니다.", flash[:notice]
    assert users(:member).reload.operator?
  end

  test "본인 역할은 변경할 수 없다" do
    sign_in
    patch admin_user_path(users(:one)), params: { user: { role: "member" } }
    assert_redirected_to admin_users_path
    assert_equal "본인 역할은 변경할 수 없습니다.", flash[:alert]
    assert users(:one).reload.admin?
  end

  test "마지막 관리자는 강등할 수 없다" do
    sign_in(users(:two))
    # 로그인 후 DB 역할을 직접 바꿔 본인 보호와 겹치지 않는 상태를 만든다.
    authenticated_admin = User.find(users(:two).id)
    users(:two).update_column(:role, User.roles[:member])
    assert_equal [ users(:one).id ], User.where(role: :admin).pluck(:id)
    # 요청의 관리자 인증만 통과시켜 마지막 관리자 보호를 독립적으로 검증한다.
    User.stub(:find_by, authenticated_admin) do
      patch admin_user_path(users(:one)), params: { user: { role: "member" } }
    end
    assert_redirected_to admin_users_path
    assert_equal "관리자가 최소 1명 필요합니다.", flash[:alert]
    assert users(:one).reload.admin?
  end

  test "존재하지 않는 역할은 거부한다" do
    sign_in
    patch admin_user_path(users(:member)), params: { user: { role: "owner" } }
    assert_redirected_to admin_users_path
    assert flash[:alert].present?
    assert users(:member).reload.member?
  end

  test "역할 외 이메일과 소속 계정은 변경하지 않는다" do
    sign_in
    user = users(:member)
    original = user.attributes.slice("email", "account_id")
    patch admin_user_path(user), params: { user: { role: "operator", email: "attack@example.com", account_id: accounts(:other).id } }
    assert_redirected_to admin_users_path
    assert user.reload.operator?
    assert_equal original, user.attributes.slice("email", "account_id")
  end

  { operator: :inventory_scan_path, member: :root_path, guest: :login_path }.each do |role, destination|
    test "#{ { operator: "운영자", member: "회원", guest: "손님" }.fetch(role) }은 사용자 목록과 역할 변경에 접근할 수 없다" do
      post login_path, params: { email: users(role).email, password: "TestPassword!2026" } unless role == :guest
      get admin_users_path
      assert_redirected_to public_send(destination)
      patch admin_user_path(users(:member)), params: { user: { role: "admin" } }
      assert_redirected_to public_send(destination)
      assert users(:member).reload.member?
    end
  end
end
