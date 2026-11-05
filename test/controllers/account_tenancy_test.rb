require "test_helper"

class AccountTenancyTest < ActionDispatch::IntegrationTest
  test "다른 계정은 관리 화면에 접근할 수 없고 자기 사용자만 표시한다" do
    post login_path, params: { email: users(:other).email, password: "TestPassword!2026" }
    assert_redirected_to workspace_path
    [ inventory_scan_path, dashboard_index_path ].each do |path|
      get path
      assert_redirected_to workspace_path
      assert_equal "이 화면은 몰 관리자 전용입니다", flash[:alert]
    end
    get workspace_path
    assert_response :success
    assert_includes response.body, users(:other).email
    assert_not_includes response.body, users(:one).email
    assert_not_includes response.body, users(:two).email
  end

  test "primary and legacy users retain mall access" do
    [ users(:one), users(:two) ].each do |user|
      sign_in(user)
      get inventory_scan_path
      assert_response :success
      get dashboard_index_path
      assert_response :success
      delete logout_path
    end
    users(:one).update!(account: nil)
    sign_in
    get inventory_scan_path
    assert_response :success
    get workspace_path
    assert_redirected_to login_path
  end

  test "workspace requires account membership" do
    get workspace_path
    assert_redirected_to login_path
  end

  test "signup flag and atomic validation" do
    previous = ENV["SAAS_SIGNUP_ENABLED"]
    ENV["SAAS_SIGNUP_ENABLED"] = "0"
    get signup_path
    assert_response :not_found
    post signup_path
    assert_response :not_found
    ENV["SAAS_SIGNUP_ENABLED"] = "true"
    get signup_path
    assert_response :success
    attributes = { account_name: "JIEUM", name: "가입자", email: "signup@example.com", password: "TestPassword!2026", password_confirmation: "mismatch" }
    assert_no_difference [ "Account.count", "User.count" ] do
      post signup_path, params: { signup: attributes }
      assert_response :unprocessable_entity
    end
    attributes[:password_confirmation] = attributes[:password]
    assert_difference [ "Account.count", "User.count" ], 1 do
      post signup_path, params: { signup: attributes }
      assert_redirected_to workspace_path
    end
    user = User.find_by!(email: attributes[:email])
    assert_equal user.id, session[:user_id]
    assert_equal "jieum-2", user.account.slug
    get workspace_path
    assert_response :success
    assert_includes response.body, user.email
  ensure
    ENV["SAAS_SIGNUP_ENABLED"] = previous
  end
end
