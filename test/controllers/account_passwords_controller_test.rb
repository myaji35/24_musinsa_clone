require "test_helper"

class AccountPasswordsControllerTest < ActionDispatch::IntegrationTest
  test "로그인이 필요하다" do
    get account_password_path
    assert_redirected_to login_path
    patch account_password_path
    assert_redirected_to login_path
  end

  test "변경 성공은 세션을 재발급하고 로그인과 변경 시각을 유지한다" do
    sign_in
    old_session_id = session.id.to_s
    users(:one).update!(must_change_password: true)
    patch account_password_path, params: password_params
    assert_redirected_to purchase_orders_path
    assert_equal "비밀번호를 바꿨습니다.", flash[:notice]
    assert_equal users(:one).id, session[:user_id]
    assert_not_equal old_session_id, session.id.to_s
    assert_not users(:one).reload.must_change_password?
    assert users(:one).password_changed_at
    assert users(:one).authenticate("NewSecret!2026")
    get inventory_scan_path
    assert_response :success
  end

  test "잘못된 현재 비밀번호 길이 재사용 확인 및 쉬운 비밀번호를 거부한다" do
    sign_in
    cases = [
      [ { current_password: "wrong" }, "현재 비밀번호가 올바르지 않습니다" ],
      [ { password: "short", password_confirmation: "short" }, "새 비밀번호는 8자 이상이어야 합니다" ],
      [ { password: "TestPassword!2026", password_confirmation: "TestPassword!2026" }, "새 비밀번호는 현재 비밀번호와 달라야 합니다" ],
      [ { password_confirmation: "different" }, "새 비밀번호 확인이 일치하지 않습니다" ]
    ]
    %w[123456 12345678 password qwerty minsu].each do |weak|
      cases << [ { password: weak, password_confirmation: weak }, "너무 쉬운 비밀번호는 사용할 수 없습니다" ]
    end
    cases.each do |overrides, message|
      patch account_password_path, params: password_params.merge(overrides)
      assert_response :unprocessable_entity
      assert_select "[role=alert]", text: /#{message}/
      assert users(:one).reload.authenticate("TestPassword!2026")
      assert_nil users(:one).password_changed_at
      assert_no_match "NewSecret!2026", response.body
    end
  end

  test "임시 비밀번호 사용자는 로그인부터 공개 관리자 변경 요청까지 강제 이동한다" do
    users(:one).update!(must_change_password: true)
    get trends_path
    post login_path, params: { email: users(:one).email, password: "TestPassword!2026" }
    assert_redirected_to account_password_path
    [ root_path, inventory_scan_path, workspace_path, login_path ].each do |path|
      get path
      assert_redirected_to account_password_path
    end
    patch product_path(products(:one)), params: { product: { name: "blocked" } }
    assert_redirected_to account_password_path
    assert_not_equal "blocked", products(:one).reload.name
    get account_password_path
    assert_response :success
    assert_select "[role=status]", text: "처음 로그인 — 임시 비밀번호를 바꿔 주세요"
    assert_select "a[href=?]", account_password_path
    delete logout_path
    assert_redirected_to root_path
    assert_nil session[:user_id]
  end

  test "다른 계정 사용자도 비밀번호를 변경한다" do
    user = users(:other)
    user.update!(must_change_password: true)
    post login_path, params: { email: user.email, password: "TestPassword!2026" }
    assert_redirected_to account_password_path
    get account_password_path
    assert_response :success
    patch account_password_path, params: password_params
    assert_redirected_to account_password_path
    assert_not user.reload.must_change_password?
  end

  test "정적 자산은 강제 이동하지 않는다" do
    sign_in
    users(:one).update!(must_change_password: true)
    get "/icon.svg"
    assert_response :success
  end

  private

  def password_params
    { current_password: "TestPassword!2026", password: "NewSecret!2026", password_confirmation: "NewSecret!2026" }
  end
end
