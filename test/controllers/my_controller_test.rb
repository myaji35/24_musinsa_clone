require "test_helper"

class MyControllerTest < ActionDispatch::IntegrationTest
  test "이름 수정 화면과 비밀번호 변경 화면에 폼과 탭을 표시한다" do
    login_member
    get my_path
    assert_select "a[href=?]", edit_my_path, text: "이름 수정"
    assert_select "a[href=?]", edit_my_password_path, text: "비밀번호 변경"
    get edit_my_path
    assert_response :success
    assert_select "input[name='user[name]']"
    assert_select "a[href=?]", my_orders_path
    get edit_my_password_path
    assert_response :success
    assert_select "input[autocomplete='current-password']", count: 1
    assert_select "input[autocomplete='new-password']", count: 2
    assert_select "a[href=?]", my_path
  end

  test "이름 수정에 성공한다" do
    login_member
    patch my_path, params: { user: { name: "새 이름" } }
    assert_redirected_to my_path
    assert_equal "내 정보를 수정했습니다.", flash[:notice]
    assert_equal "새 이름", users(:member).reload.name
  end

  test "공백 이름은 오류와 함께 거절한다" do
    login_member
    original_name = users(:member).name
    patch my_path, params: { user: { name: "   " } }
    assert_response :unprocessable_entity
    assert_select "ul[role='alert'] li", text: "이름을 입력해 주세요."
    assert_equal original_name, users(:member).reload.name
  end

  test "이름과 함께 보낸 이메일 역할 계정은 변경하지 않는다" do
    login_member
    user = users(:member)
    original = user.attributes.slice("email", "role", "account_id")
    patch my_path, params: { user: { name: "새 이름", email: "changed@example.com", role: "admin", account_id: accounts(:jieum).id } }
    assert_redirected_to my_path
    assert_equal "새 이름", user.reload.name
    assert_equal original, user.attributes.slice("email", "role", "account_id")
  end

  test "비밀번호 변경 후 로그인은 유지되고 새 비밀번호로만 로그인한다" do
    login_member
    patch my_password_path, params: password_change_params
    assert_redirected_to my_path
    assert_equal "비밀번호를 변경했습니다.", flash[:notice]
    assert_equal users(:member).id, session[:user_id]
    follow_redirect!
    assert_response :success
    delete logout_path
    post login_path, params: { email: users(:member).email, password: "TestPassword!2026" }
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
    post login_path, params: { email: users(:member).email, password: "NewPassword!2026" }
    assert_equal users(:member).id, session[:user_id]
    assert_redirected_to root_path
  end

  test "현재 비밀번호가 틀리면 변경하지 않는다" do
    assert_password_change_rejected({ current_password: "wrong" }, "현재 비밀번호가 올바르지 않습니다.")
  end

  test "현재와 같은 비밀번호는 거절한다" do
    assert_password_change_rejected({ password: "TestPassword!2026", password_confirmation: "TestPassword!2026" }, "현재와 다른 비밀번호를 입력해 주세요.")
  end

  test "새 비밀번호가 비어 있으면 변경하지 않는다" do
    assert_password_change_rejected({ password: "", password_confirmation: "" }, "새 비밀번호를 입력해 주세요.")
    delete logout_path
    login_member
    assert_redirected_to root_path
    assert_equal users(:member).id, session[:user_id]
  end

  test "새 비밀번호가 여덟 자 미만이면 거절한다" do
    assert_password_change_rejected({ password: "short", password_confirmation: "short" })
  end

  test "새 비밀번호 확인이 다르면 거절한다" do
    assert_password_change_rejected({ password_confirmation: "DifferentPassword!2026" })
  end

  test "손님은 이름 수정과 비밀번호 변경 네 경로에서 로그인으로 이동한다" do
    get edit_my_path
    assert_redirected_to login_path
    patch my_path, params: { user: { name: "새 이름" } }
    assert_redirected_to login_path
    get edit_my_password_path
    assert_redirected_to login_path
    patch my_password_path, params: password_change_params
    assert_redirected_to login_path
  end

  test "손님은 로그인 후 내 정보로 복귀한다" do
    get my_path
    assert_redirected_to login_path
    assert_equal "로그인이 필요합니다.", flash[:alert]
    assert_equal my_path, session[:return_to]

    post login_path, params: { email: users(:member).email, password: "TestPassword!2026" }
    assert_redirected_to my_path
    follow_redirect!
    assert_response :success
  end

  test "회원과 운영자와 관리자 모두 내 정보와 한국어 역할을 확인한다" do
    { member: "일반 회원", operator: "운영자", one: "관리자" }.each do |fixture, label|
      user = users(fixture)
      post login_path, params: { email: user.email, password: "TestPassword!2026" }
      get my_path
      assert_response :success
      assert_select "dd", text: user.name
      assert_select "dd", text: user.email
      assert_select "dd", text: label
      assert_select "dd", text: user.created_at.strftime("%Y-%m-%d")
      assert_select "a[href=?]", my_path, text: "내 정보"
      assert_select "a[href=?]", my_orders_path, text: "내 주문"
      assert_select "form[action=?]", logout_path
      delete logout_path
    end
  end

  test "내 주문은 빈 상태와 비회원 주문조회 링크를 표시한다" do
    post login_path, params: { email: users(:member).email, password: "TestPassword!2026" }
    get my_orders_path
    assert_response :success
    assert_select "p", text: "아직 회원으로 주문한 내역이 없습니다. 로그인 전에 한 주문은 주문조회에서 확인하세요."
    assert_select "a[href=?]", orders_lookup_path, text: "주문조회"
    assert_select "form[action=?]", logout_path
  end

  test "내 주문에는 로그인한 회원의 주문만 표시한다" do
    member = users(:member)
    other_member = User.create!(email: "member-b@example.com", name: "회원 B",
                                password: "TestPassword!2026", role: :member)
    order = orders(:one)
    order.update!(user: member)
    post login_path, params: { email: member.email, password: "TestPassword!2026" }
    get my_orders_path
    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "td", text: order.order_number
    assert_select "td", text: order.product.name
    assert_select "td", text: "#{order.variant.color} / #{order.variant.size}"
    assert_select "td", text: order.quantity.to_s
    assert_select "td", text: "₩ 39,800"
    assert_select "td", text: "결제 완료"
    assert_select "td", text: order.created_at.strftime("%Y.%m.%d")

    delete logout_path
    post login_path, params: { email: other_member.email, password: "TestPassword!2026" }
    get my_orders_path
    assert_response :success
    assert_not_includes response.body, order.order_number
    assert_select "p", text: "아직 회원으로 주문한 내역이 없습니다. 로그인 전에 한 주문은 주문조회에서 확인하세요."
  end

  test "손님은 내 주문에 접근할 때 로그인으로 이동한다" do
    get my_orders_path
    assert_redirected_to login_path
    assert_equal my_orders_path, session[:return_to]
  end

  private

  def login_member
    post login_path, params: { email: users(:member).email, password: "TestPassword!2026" }
  end

  def password_change_params(overrides = {})
    { password_change: { current_password: "TestPassword!2026", password: "NewPassword!2026",
                         password_confirmation: "NewPassword!2026" }.merge(overrides) }
  end

  def assert_password_change_rejected(overrides, message = nil)
    login_member
    digest = users(:member).password_digest
    patch my_password_path, params: password_change_params(overrides)
    assert_response :unprocessable_entity
    assert_select "ul[role='alert'] li", minimum: 1
    assert_select "ul[role='alert'] li", text: message if message
    assert_equal digest, users(:member).reload.password_digest
    assert_equal users(:member).id, session[:user_id]
  end
end
