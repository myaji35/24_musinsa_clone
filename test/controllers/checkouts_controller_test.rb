require "test_helper"

class CheckoutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @address = { recipient_name: "홍길동", phone: "010-7777-9876", postal_code: "06123",
                 address1: "서울시 테스트로 1", address2: "비밀상세 201호" }
  end

  test "빈 장바구니는 주문서를 열 수 없다" do
    get new_checkout_path
    assert_redirected_to cart_path
    post checkout_path, params: { checkout: @address }
    assert_redirected_to cart_path
  end

  test "동의와 주소 검증 실패는 입력값을 유지한다" do
    post cart_items_path, params: { variant_id: variants(:one).id }
    get new_checkout_path
    assert_response :success
    assert_includes response.body, "#{Rails.configuration.x.shipping_address_retention_days}일"
    assert_includes response.body, variants(:one).product.name
    assert_select 'input[name="checkout[save_consent]"]', count: 0
    assert_no_difference "Order.count" do
      post checkout_path, params: { checkout: @address }
    end
    assert_response :unprocessable_entity
    assert_select 'input[name="checkout[phone]"][value="010-7777-9876"]'
    post checkout_path, params: { checkout: @address.merge(privacy_consent: "1", postal_code: "bad") }
    assert_response :unprocessable_entity
    assert_select 'input[name="checkout[address2]"][value="비밀상세 201호"]'
  end

  test "로그인 없이 주문을 만들고 장바구니를 비우며 완료 내역을 연다" do
    post cart_items_path, params: { variant_id: variants(:one).id, quantity: 2 }
    assert_difference "Order.count", 1 do
      post checkout_path, params: { checkout: @address.merge(privacy_consent: "1") }
    end
    order = Order.order(:id).last
    assert_equal "pending", order.status
    assert_not order.shipping_address.save_consent?
    assert_redirected_to customer_order_path(order.checkout_number)
    follow_redirect!
    assert_response :success
    assert_includes response.body, "결제 기능은 준비 중입니다. 담당자가 확인 후 안내드립니다."
    get cart_path
    assert_includes response.body, "장바구니가 비어 있습니다"
  end
end
