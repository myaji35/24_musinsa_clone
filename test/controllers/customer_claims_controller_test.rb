require "test_helper"

class CustomerClaimsControllerTest < ActionDispatch::IntegrationTest
  setup do
    result = Orders::Intake.call(items: [ { variant_id: variants(:one).id, quantity: 1 } ],
      address: { recipient_name: "홍길동", phone: "010-7777-9876", postal_code: "06123", address1: "서울시 테스트로 1" })
    @order = result.orders.first
  end

  test "조회 인증이 없으면 폼과 제출 모두 조회 화면으로 이동한다" do
    get new_customer_order_claim_path(@order.checkout_number, order_id: @order.id)
    assert_redirected_to orders_lookup_path
    assert_no_difference "OrderClaim.count" do
      submit_claim
    end
    assert_redirected_to orders_lookup_path
  end

  test "다른 주문서의 주문 번호로 폼을 보거나 요청할 수 없다" do
    verify_checkout
    other_order = orders(:one)
    get new_customer_order_claim_path(@order.checkout_number, order_id: other_order.id)
    assert_response :not_found
    assert_no_difference "OrderClaim.count" do
      submit_claim(order_id: other_order.id)
    end
    assert_response :not_found
  end

  test "인증한 주문은 폼을 보고 비회원 취소를 요청할 수 있다" do
    verify_checkout
    get new_customer_order_claim_path(@order.checkout_number, order_id: @order.id)
    assert_response :success
    assert_select "h1", text: "취소 요청"
    assert_select "input[type=radio][value=cancel][checked]"
    assert_select "p", text: /반품·교환은 배송 완료/, count: 0
    assert_select "a[href=?]", customer_order_path(@order.checkout_number), text: "돌아가기"
    assert_difference "OrderClaim.count", 1 do
      submit_claim
    end
    assert_redirected_to customer_order_path(@order.checkout_number)
    claim = @order.order_claims.last
    assert_equal "guest", claim.requester
    assert_nil claim.user
    assert_equal "completed", claim.status
    follow_redirect!
    assert_select "p", text: "취소 완료"
  end

  private

  def verify_checkout
    post orders_lookup_path, params: { checkout_number: @order.checkout_number, phone_suffix: "9876" }
    assert_redirected_to customer_order_path(@order.checkout_number)
  end

  def submit_claim(order_id: @order.id)
    post customer_order_claims_path(@order.checkout_number), params: { order_id: order_id,
      order_claim: { kind: "cancel", reason_code: "other", detail: "취소 요청" } }
  end
end
