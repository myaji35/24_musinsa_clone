require "test_helper"

class MemberSignupsControllerTest < ActionDispatch::IntegrationTest
  test "회원가입하면 계정 없는 일반 회원으로 저장하고 로그인한다" do
    get join_path
    assert_response :success
    assert_select "h1", text: "회원가입"
    post_signup
    assert_redirected_to root_path
    user = User.find_by!(email: "new-member@example.com")
    assert user.member?
    assert_nil user.account
    assert_equal user.id, session[:user_id]
    assert_equal "회원가입이 완료되었습니다.", flash[:notice]
  end

  test "관리자 역할과 계정을 섞어 보내도 계정 없는 일반 회원으로 저장한다" do
    post_signup(role: "admin", account_id: accounts(:jieum).id)
    assert_redirected_to root_path
    user = User.find_by!(email: "new-member@example.com")
    assert user.member?
    assert_nil user.account
  end

  test "비밀번호 확인이 다르면 가입할 수 없다" do
    assert_signup_rejected(password_confirmation: "DifferentPassword!2026")
  end

  test "비밀번호가 여덟 자 미만이면 가입할 수 없다" do
    assert_signup_rejected(password: "short12", password_confirmation: "short12")
  end

  test "이메일은 대소문자를 무시하고 중복 가입을 막는다" do
    assert_signup_rejected(email: users(:member).email.upcase)
  end

  test "이름을 누락하면 가입할 수 없다" do
    assert_signup_rejected(name: nil)
  end

  test "이름이 공백이면 가입할 수 없다" do
    assert_signup_rejected(name: "   ")
  end

  test "로그인한 사용자가 가입 화면에 접근하면 홈으로 이동한다" do
    sign_in
    get join_path
    assert_redirected_to root_path
    assert_equal "이미 로그인되어 있습니다.", flash[:notice]
  end

  test "로그인한 사용자는 회원가입 요청을 할 수 없다" do
    sign_in
    assert_no_difference "User.count" do
      post_signup
    end
    assert_redirected_to root_path
    assert_equal "이미 로그인되어 있습니다.", flash[:notice]
  end

  test "가입한 회원이 재고 스캔에 접근하면 홈으로 거부한다" do
    post_signup
    get inventory_scan_path
    assert_redirected_to root_path
  end

  private

  def post_signup(**overrides)
    post join_path, params: { member: {
      name: "새 회원", email: "new-member@example.com",
      password: "TestPassword!2026", password_confirmation: "TestPassword!2026"
    }.merge(overrides) }
  end

  def assert_signup_rejected(**overrides)
    assert_no_difference "User.count" do
      post_signup(**overrides)
    end
    assert_response :unprocessable_entity
    assert_select "[role=alert] li", minimum: 1
    assert_nil session[:user_id]
  end
end
