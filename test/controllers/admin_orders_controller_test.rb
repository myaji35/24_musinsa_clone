require "test_helper"

class AdminOrdersControllerTest < ActionDispatch::IntegrationTest
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
