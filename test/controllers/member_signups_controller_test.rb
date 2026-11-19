require "test_helper"

class MemberSignupsControllerTest < ActionDispatch::IntegrationTest
  test "가입 화면에 전달한 경로로 가입 후 복귀한다" do
    get join_path(return_to: cart_path)
    post_signup
    assert_redirected_to cart_path
  end

  test "손님 장바구니는 회원가입 뒤에도 유지된다" do
    post cart_items_path, params: { variant_id: variants(:one).id, quantity: 2 }
    post_signup
    assert_redirected_to root_path

    get cart_path
    assert_response :success
    assert_includes response.body, products(:one).name
  end

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

  {
    terms_agreement: "이용약관에 동의해 주세요.",
    privacy_agreement: "개인정보 수집·이용에 동의해 주세요.",
    age_confirmation: "만 14세 이상만 가입할 수 있습니다."
  }.each do |consent, message|
    test "#{message} 동의가 누락되면 가입할 수 없다" do
      assert_signup_rejected(**{ consent => nil })
      assert_select "[role=alert] li", text: message
      ([ :terms_agreement, :privacy_agreement, :age_confirmation ] - [ consent ]).each do |retained|
        assert_select "input[name='member[#{retained}]'][checked]"
      end
    end
  end

  test "이름과 필수 동의를 누락하면 모든 오류를 함께 표시한다" do
    assert_signup_rejected(name: nil, terms_agreement: nil, privacy_agreement: nil, age_confirmation: nil)
    assert_select "[role=alert] li", text: /을 입력해 주세요\./
    assert_select "[role=alert] li", text: "이용약관에 동의해 주세요."
    assert_select "[role=alert] li", text: "개인정보 수집·이용에 동의해 주세요."
    assert_select "[role=alert] li", text: "만 14세 이상만 가입할 수 있습니다."
  end

  test "회원가입에 성공하면 필수 동의 시각을 저장한다" do
    freeze_time do
      post_signup
      assert_redirected_to root_path
      user = User.find_by!(email: "new-member@example.com")
      assert_equal Time.current, user.terms_agreed_at
      assert_equal Time.current, user.privacy_agreed_at
      assert_equal Time.current, user.age_confirmed_at
    end
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
      password: "TestPassword!2026", password_confirmation: "TestPassword!2026",
      terms_agreement: "1", privacy_agreement: "1", age_confirmation: "1"
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
