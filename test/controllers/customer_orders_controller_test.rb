require "test_helper"

class CustomerOrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    result = Orders::Intake.call(items: [ { variant_id: variants(:one).id, quantity: 2 } ],
      address: { recipient_name: "홍길동", phone: "010-7777-9876", postal_code: "06123",
                 address1: "서울시 테스트로 1", address2: "비밀상세 201호" })
    @order = result.orders.first
  end

  test "세션 미허용 주문은 조회 폼으로 이동한다" do
    get customer_order_path(@order.checkout_number)
    assert_redirected_to orders_lookup_path
    get orders_lookup_path
    assert_response :success
  end

  test "틀린 뒤 네 자리는 거부하고 올바르면 마스킹된 내역을 허용한다" do
    post orders_lookup_path, params: { checkout_number: @order.checkout_number, phone_suffix: "0000" }
    assert_response :unprocessable_entity
    get customer_order_path(@order.checkout_number)
    assert_redirected_to orders_lookup_path
    post orders_lookup_path, params: { checkout_number: @order.checkout_number, phone_suffix: "9876" }
    assert_redirected_to customer_order_path(@order.checkout_number)
    follow_redirect!
    assert_response :success
    assert_includes response.body, "홍*"
    assert_includes response.body, "010-****-9876"
    assert_not_includes response.body, "홍길동"
    assert_not_includes response.body, "7777"
    assert_not_includes response.body, "비밀상세 201호"
  end

  test "배송지 파기 뒤에도 본인 확인 후 파기 안내를 표시한다" do
    @order.shipping_address.destroy!
    post orders_lookup_path, params: { checkout_number: @order.checkout_number, phone_suffix: "9876" }
    follow_redirect!
    assert_response :success
    assert_includes response.body, "배송지 정보는 보관 기간이 지나 파기되었습니다"
  end
end
