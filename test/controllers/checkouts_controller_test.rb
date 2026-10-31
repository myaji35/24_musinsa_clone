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

  test "계좌 미설정이면 주문서에 계좌 준비 중 안내를 표시한다" do
    with_payout_env({}) do
      post cart_items_path, params: { variant_id: variants(:one).id }
      get new_checkout_path
      assert_response :success
      assert_select '[data-testid="checkout-payment-note"]', text: "결제는 주문 후 계좌이체로 진행됩니다. 입금 계좌는 준비 중이며, 준비되면 주문조회(주문서 번호 + 휴대폰 뒤 4자리)에서 확인하실 수 있습니다."
      assert_not_includes response.body, "주문 완료 화면에서 입금 계좌 안내"
    end
  end

  test "계좌 설정이 있으면 주문서에 완료 화면의 입금 계좌 안내를 예고한다" do
    with_payout_env("PAYOUT_BANK" => "테스트은행", "PAYOUT_ACCOUNT" => "000-00-000000", "PAYOUT_HOLDER" => "테스트예금주") do
      post cart_items_path, params: { variant_id: variants(:one).id }
      get new_checkout_path
      assert_response :success
      assert_select '[data-testid="checkout-payment-note"]', text: "결제는 주문 후 계좌이체로 진행됩니다(주문 완료 화면에서 입금 계좌 안내)"
    end
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
    assert_select "#payment-instruction"
    assert_includes response.body, "주문이 접수되었습니다."
    get cart_path
    assert_includes response.body, "장바구니가 비어 있습니다"
  end
  private

  def with_payout_env(values)
    keys = %w[PAYOUT_BANK PAYOUT_ACCOUNT PAYOUT_HOLDER PAYOUT_DUE_DAYS PAYOUT_CONTACT]
    previous = ENV.to_h.slice(*keys)
    keys.each { |key| ENV.delete(key) }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    keys.each { |key| ENV[key] = previous[key] }
  end
end
