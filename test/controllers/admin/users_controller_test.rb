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

  test "이름과 이메일로 사용자를 검색한다" do
    sign_in
    [ " 최회원 ", "member@example.com" ].each do |q|
      get admin_users_path, params: { q: q }
      assert_response :success
      assert_select "tbody tr", count: 1
      assert_select "td", text: users(:member).email
      assert_select "p", text: "총 1명"
    end
  end

  test "역할과 상태 필터를 함께 적용한다" do
    users(:member).update!(suspended_at: Time.current)
    sign_in
    get admin_users_path, params: { role: "member", status: "suspended" }
    assert_select "tbody tr", count: 1
    assert_select "td", text: users(:member).email
    get admin_users_path, params: { role: "member", status: "active" }
    assert_select "td", text: users(:other).email
    assert_select "td", text: users(:member).email, count: 0
    get admin_users_path, params: { role: "admin" }
    assert_select "tbody tr", count: User.where(role: :admin).count
    get admin_users_path, params: { role: "owner", status: "invalid" }
    assert_select "tbody tr", count: User.count
  end

  test "퍼센트 검색어는 와일드카드가 아니라 문자로 검색한다" do
    users(:member).update!(name: "100%회원")
    sign_in
    get admin_users_path, params: { q: "%" }
    assert_select "tbody tr", count: 1
    assert_select "td", text: users(:member).email
    get admin_users_path, params: { q: "없는 검색어" }
    assert_select "tbody tr", count: 0
    assert_select "p", text: "조건에 맞는 사용자가 없습니다."
  end

  test "검색 결과는 최신 가입 순으로 스무 명씩 나눠 본다" do
    21.times do |i|
      User.create!(name: "페이지회원#{i}", email: "page#{i}@example.com",
        password: "TestPassword!2026", created_at: i.minutes.ago)
    end
    sign_in
    filters = { q: "페이지회원", role: "member", status: "active" }
    get admin_users_path, params: filters.merge(page: 0)
    assert_select "tbody tr", count: 20
    assert_select "tbody tr:first-child td:first-child", text: "페이지회원0"
    assert_select "p", text: "총 21명"
    assert_select "a[href=?]", admin_users_path(filters.merge(page: 2)), text: "다음"
    get admin_users_path, params: filters.merge(page: 2)
    assert_select "tbody tr", count: 1
    assert_select "td", text: "page20@example.com"
    assert_select "a[href=?]", admin_users_path(filters.merge(page: 1)), text: "이전"
    assert_select "a", text: "다음", count: 0
  end

  test "회원 정지와 해제 후 검색 조건과 페이지를 유지한다" do
    sign_in
    user = users(:member)
    filters = { q: "회원", role: "member", status: "active", page: "2" }
    patch suspend_admin_user_path(user), params: filters
    assert_redirected_to admin_users_path(filters)
    assert_equal "계정을 정지했습니다.", flash[:notice]
    assert user.reload.suspended?
    patch unsuspend_admin_user_path(user), params: filters
    assert_redirected_to admin_users_path(filters)
    assert_equal "계정 정지를 해제했습니다.", flash[:notice]
    assert_nil user.reload.suspended_at
  end

  test "본인과 다른 관리자 계정은 정지할 수 없다" do
    sign_in
    { one: "본인 계정은 정지할 수 없습니다.",
      two: "관리자 계정은 먼저 역할을 바꾼 뒤 정지해 주세요." }.each do |fixture, message|
      patch suspend_admin_user_path(users(fixture))
      assert_redirected_to admin_users_path
      assert_equal message, flash[:alert]
      assert_not users(fixture).reload.suspended?
    end
    get admin_users_path
    [ :one, :two ].each do |fixture|
      assert_select "form[action=?]", suspend_admin_user_path(users(fixture)), count: 0
    end
  end

  test "표와 모바일 카드에 정지 상태와 해제 버튼을 표시한다" do
    users(:member).update!(suspended_at: Time.current)
    sign_in
    get admin_users_path
    [ "table", "ul" ].each do |container|
      assert_select "#{container} form[action=?]", unsuspend_admin_user_path(users(:member))
      assert_select container, text: /정지일 #{users(:member).suspended_at.strftime("%Y-%m-%d")}/
    end
  end

  { operator: :inventory_scan_path, member: :root_path, guest: :login_path }.each do |role, destination|
    test "#{ { operator: "운영자", member: "회원", guest: "손님" }.fetch(role) }은 사용자 목록과 역할 변경 및 정지와 해제에 접근할 수 없다" do
      post login_path, params: { email: users(role).email, password: "TestPassword!2026" } unless role == :guest
      get admin_users_path
      assert_redirected_to public_send(destination)
      patch admin_user_path(users(:member)), params: { user: { role: "admin" } }
      assert_redirected_to public_send(destination)
      assert users(:member).reload.member?
      patch suspend_admin_user_path(users(:member))
      assert_redirected_to public_send(destination)
      assert_not users(:member).reload.suspended?
      users(:other).update!(suspended_at: Time.current)
      patch unsuspend_admin_user_path(users(:other))
      assert_redirected_to public_send(destination)
      assert users(:other).reload.suspended?
    end
  end
end
