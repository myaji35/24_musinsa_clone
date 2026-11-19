require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "로그인 화면에 전달한 경로로 로그인 후 복귀한다" do
    get login_path(return_to: cart_path)
    assert_select '[data-controller=password-visibility] button[aria-label="비밀번호 보기"]'
    post login_path, params: { email: users(:member).email, password: "TestPassword!2026" }
    assert_redirected_to cart_path
  end

  test "로그인 화면에 전달한 외부 경로는 무시한다" do
    [ "https://evil.example", "//evil" ].each do |path|
      get login_path(return_to: path)
      assert_nil session[:return_to]
      post login_path, params: { email: users(:member).email, password: "TestPassword!2026" }
      assert_redirected_to root_path
      delete logout_path
    end
  end

  test "손님 장바구니는 로그인 뒤에도 유지된다" do
    post cart_items_path, params: { variant_id: variants(:one).id, quantity: 2 }
    post login_path, params: { email: users(:member).email, password: "TestPassword!2026" }
    assert_redirected_to root_path

    get cart_path
    assert_response :success
    assert_includes response.body, products(:one).name
  end

  test "로그인한 관리자가 로그인 화면에 접근하면 재고 스캔으로 이동한다" do
    sign_in
    get login_path
    assert_redirected_to inventory_scan_path
  end

  test "로그인한 회원이 로그인 화면에 접근하면 홈으로 이동한다" do
    post login_path, params: { email: users(:member).email, password: "TestPassword!2026" }
    get login_path
    assert_redirected_to root_path
  end

  test "로그인 후 원래 관리자 화면과 쿼리로 복귀한다" do
    [ trends_path, "#{dashboard_index_path}?range=7" ].each do |path|
      delete logout_path
      get path
      assert_redirected_to login_path
      assert_equal path, session[:return_to]

      post login_path, params: { email: users(:one).email, password: "TestPassword!2026" }
      assert_redirected_to path
      assert_equal users(:one).id, session[:user_id]
      assert_nil session[:return_to]
    end
  end

  test "POST와 HTML이 아닌 요청은 복귀 경로를 저장하지 않는다" do
    post trends_path
    assert_redirected_to login_path
    assert_nil session[:return_to]

    get trends_path, as: :json
    assert_redirected_to login_path
    assert_nil session[:return_to]
    sign_in
  end

  test "로그인 실패 후에도 복귀 경로를 보존한다" do
    get trends_path
    post login_path, params: { email: users(:one).email, password: "wrong" }
    assert_response :unprocessable_entity
    assert_equal trends_path, session[:return_to]
    post login_path, params: { email: users(:one).email, password: "TestPassword!2026" }
    assert_redirected_to trends_path
  end

  test "비로그인 재고 스캔 접근은 로그인으로 이동한다" do
    get inventory_scan_path
    assert_response :found
    assert_redirected_to login_path
  end

  test "로그인 후 재고 스캔에 접근하고 사용자 이름과 로그아웃을 표시한다" do
    sign_in
    assert_equal users(:one).id, session[:user_id]
    get inventory_scan_path
    assert_response :success
    assert_select "span", text: users(:one).name
    assert_select "form[action=?]", logout_path
  end

  test "상품 관리 액션은 모두 인증이 필요하다" do
    product = products(:one)
    get new_product_path
    assert_redirected_to login_path
    get edit_product_path(product)
    assert_redirected_to login_path
    assert_no_difference "Product.count" do
      post products_path, params: { product: { name: "무인증 상품", price: 1000 } }
      assert_redirected_to login_path
      delete product_path(product)
      assert_redirected_to login_path
    end
    patch product_path(product), params: { product: { name: "무인증 변경" } }
    assert_redirected_to login_path
    assert_not_equal "무인증 변경", product.reload.name
  end

  test "공개 페이지는 로그인 없이 접근한다" do
    [ root_path, products_path, product_path(products(:one)),
      snaps_path, snap_path(snaps(:one)), rails_health_check_path,
      pwa_manifest_path(format: :json), pwa_service_worker_path(format: :js), login_path ].each do |path|
      get path
      assert_response :success
    end

    get search_path(q: "셔츠")
    assert_redirected_to root_path(q: "셔츠")
  end

  test "거래처 토큰 확인은 로그인 없이 가능하다" do
    order = purchase_orders(:one)
    get confirm_purchase_order_path(order.confirmation_token)
    assert_response :success
    order.update!(status: "submitted")
    post confirm_purchase_order_path(order.confirmation_token)
    assert_response :success
    assert_equal "confirmed", order.reload.status
  end

  test "잘못된 비밀번호와 미등록 이메일은 오류를 표시한다" do
    [ users(:one).email, "unknown@example.com" ].each do |email|
      post login_path, params: { email: email, password: "wrong" }
      assert_response :unprocessable_entity
      assert_select "[role=alert]", text: "이메일 또는 비밀번호가 올바르지 않습니다."
      assert_nil session[:user_id]
    end
  end

  test "비밀번호가 없는 기존 사용자는 로그인할 수 없다" do
    users(:one).update_column(:password_digest, nil)
    post login_path, params: { email: users(:one).email, password: "anything" }
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  test "정지 계정은 비밀번호가 맞아도 로그인할 수 없다" do
    users(:member).update!(suspended_at: Time.current)
    post login_path, params: { email: users(:member).email, password: "TestPassword!2026" }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: "이용이 정지된 계정입니다. 고객센터로 문의해 주세요."
    assert_nil session[:user_id]
  end

  test "정지 계정도 비밀번호가 틀리면 일반 로그인 오류만 표시한다" do
    users(:member).update!(suspended_at: Time.current)
    post login_path, params: { email: users(:member).email, password: "wrong" }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: "이메일 또는 비밀번호가 올바르지 않습니다."
    assert_nil session[:user_id]
  end

  test "로그인 중 정지된 관리자는 다음 관리 화면 요청에서 로그아웃된다" do
    sign_in
    users(:one).update!(suspended_at: Time.current)
    get admin_users_path
    assert_redirected_to login_path
    assert_nil session[:user_id]
  end

  test "로그인 중 정지된 회원은 다음 공개 화면 요청에서도 로그아웃된다" do
    post login_path, params: { email: users(:member).email, password: "TestPassword!2026" }
    assert_redirected_to root_path
    users(:member).update!(suspended_at: Time.current)
    get root_path
    assert_response :success
    assert_nil session[:user_id]
  end

  test "로그아웃 후 보호된 페이지에 접근할 수 없다" do
    sign_in
    delete logout_path
    assert_redirected_to root_path
    assert_nil session[:user_id]
    get inventory_scan_path
    assert_redirected_to login_path
  end

  test "삭제된 사용자의 세션은 접근을 허용하지 않는다" do
    user = User.create!(email: "removed@example.com", password: "TestPassword!2026", role: :admin)
    sign_in(user)
    user.destroy!
    get inventory_scan_path
    assert_redirected_to login_path
  end

  test "계정 없는 일반 회원은 관리 화면에 접근할 수 없다" do
    user = User.create!(email: "member-noacct@example.com", password: "TestPassword!2026")
    post login_path, params: { email: user.email, password: "TestPassword!2026" }

    get inventory_scan_path
    assert_response :redirect
    assert_not_equal login_url, response.location
    assert_not_equal inventory_scan_url, response.location
  end
end

class SessionsReturnPathTest < ActionController::TestCase
  tests SessionsController

  test "안전하지 않은 복귀 경로는 기본 화면으로 이동한다" do
    [ "https://evil.com", "//evil.com", "/\\evil.com", "/login", "/login?next=/trends",
      "/logout", "/logout?next=/trends", "/login/", "/join", "/join?next=/cart", "/%", "trends", nil ].each do |path|
      session[:return_to] = path
      session[:old_session_value] = "discard"
      post :create, params: { email: users(:one).email, password: "TestPassword!2026" }
      assert_redirected_to inventory_scan_path
      assert_equal users(:one).id, session[:user_id]
      assert_nil session[:return_to]
      assert_nil session[:old_session_value]
    end
  end
end
