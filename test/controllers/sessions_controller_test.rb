require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
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
    [ root_path, products_path, product_path(products(:one)), search_path,
      snaps_path, snap_path(snaps(:one)), "/api/v1/ucp/products", rails_health_check_path,
      pwa_manifest_path(format: :json), pwa_service_worker_path(format: :js), login_path ].each do |path|
      get path
      assert_response :success
    end
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

  test "로그아웃 후 보호된 페이지에 접근할 수 없다" do
    sign_in
    delete logout_path
    assert_redirected_to root_path
    assert_nil session[:user_id]
    get inventory_scan_path
    assert_redirected_to login_path
  end

  test "삭제된 사용자의 세션은 접근을 허용하지 않는다" do
    user = User.create!(email: "removed@example.com", password: "TestPassword!2026")
    sign_in(user)
    user.destroy!
    get inventory_scan_path
    assert_redirected_to login_path
  end
end
