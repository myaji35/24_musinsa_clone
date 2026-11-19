require "test_helper"

class AdminOrdersControllerTest < ActionDispatch::IntegrationTest
  test "관리자는 플랫폼 캐릭터 영상별 집계와 유입을 본다" do
    sign_in
    character = Character.create!(name: "하린", handle: "SeoHARIN")
    orders(:one).update!(source_platform: "youtube", source_character_id: character.id, source_video_id: "video-1")
    get admin_orders_path
    assert_response :success
    %w[유입원별집계 플랫폼별 캐릭터별 영상별 주문수 매출합계].each do |label|
      assert_includes response.body.gsub(/\s/, ""), label
    end
    assert_includes response.body, "youtube · 하린 · video-1"
  end

  test "주문 상태 필터는 허용된 상태만 적용한다" do
    sign_in
    get admin_orders_path(status: "paid")
    assert_response :success
    assert_includes response.body, orders(:one).order_number
    assert_not_includes response.body, orders(:two).order_number
    assert_select 'a[aria-current="page"]', text: "결제 완료"

    get admin_orders_path(status: "invalid")
    assert_response :success
    assert_includes response.body, orders(:one).order_number
    assert_includes response.body, orders(:two).order_number
    assert_select 'a[aria-current="page"]', text: "전체"
  end

  test "admin confirms only pending orders" do
    sign_in
    order = orders(:one)
    order.update!(status: "pending")
    get admin_orders_path
    assert_response :success
    assert_select "button", text: "입금 확인"
    patch confirm_payment_admin_order_path(order)
    assert_redirected_to admin_orders_path
    assert_equal "paid", order.reload.status
    order.update!(status: "cancelled")
    patch confirm_payment_admin_order_path(order)
    assert_equal "cancelled", order.reload.status
    assert flash[:alert].present?
  end

  test "account members and visitors cannot confirm payments" do
    order = orders(:one)
    order.update!(status: "pending")
    post login_path, params: { email: users(:other).email, password: "TestPassword!2026" }
    patch confirm_payment_admin_order_path(order)
    assert_redirected_to workspace_path
    assert_equal "pending", order.reload.status
    delete logout_path
    patch confirm_payment_admin_order_path(order)
    assert_redirected_to login_path
    assert_equal "pending", order.reload.status
  end
end
