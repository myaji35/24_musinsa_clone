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

  test "소문자와 앞뒤 공백이 있는 주문서 번호는 정규화하여 조회한다" do
    verify_order(checkout_number: "  " + @order.checkout_number.downcase + " ", phone_suffix: " 9876 ")
  end

  test "소문자와 앞뒤 공백이 있는 주문서 번호도 틀린 뒤 네 자리는 거부한다" do
    post orders_lookup_path, params: { checkout_number: "  " + @order.checkout_number.downcase + " ", phone_suffix: "0000" }
    assert_response :unprocessable_entity
    assert_includes response.body, "주문서 번호 또는 휴대폰 뒤 4자리를 확인해 주세요"
  end

  test "배송지 파기 뒤에도 본인 확인 후 파기 안내를 표시한다" do
    @order.shipping_address.destroy!
    post orders_lookup_path, params: { checkout_number: @order.checkout_number, phone_suffix: "9876" }
    follow_redirect!
    assert_response :success
    assert_includes response.body, "배송지 정보는 보관 기간이 지나 파기되었습니다"
  end
  test "계좌 설정이 있으면 조회 후 입금 안내를 표시한다" do
    with_payout_env("PAYOUT_BANK" => "테스트은행", "PAYOUT_ACCOUNT" => "000-00-000000",
                    "PAYOUT_HOLDER" => "테스트예금주", "PAYOUT_CONTACT" => "테스트 문의처") do
      @order.update!(created_at: Time.utc(2026, 10, 1, 16))
      paid_order = @order.dup
      paid_order.assign_attributes(order_number: nil, status: "paid", total_price: 999, created_at: Time.utc(2026, 9, 30, 16))
      paid_order.save!
      verify_order
      %w[테스트은행 000-00-000000 테스트예금주].each { |value| assert_includes response.body, value }
      assert_includes response.body, "2026년 10월 4일까지"
      assert_select "#payment-instruction", text: /입금 금액: #{ActiveSupport::NumberHelper.number_to_delimited(@order.total_price.to_i)}원/
      assert_includes response.body, "문의: 테스트 문의처"
      assert_select '[data-testid="payment-contact-link"]', count: 0
      assert_not_includes response.body, "결제 기능은 준비 중입니다"
    end
  end

  test "계좌 미설정이면 주문 접수와 주문서 번호 보관 안내 및 문의 링크를 표시한다" do
    with_payout_env("PAYOUT_BANK" => " ", "PAYOUT_ACCOUNT" => "000-00-000000", "PAYOUT_HOLDER" => "테스트예금주") do
      verify_order
      assert_includes response.body, "결제 안내를 준비 중입니다"
      assert_select 'a[data-testid="payment-contact-link"]', count: 1, text: "결제 문의하기" do |links|
        assert_equal new_feedback_path, links.first["href"]
      end
      assert_includes response.body, "주문이 접수되었습니다"
      assert_includes response.body, @order.checkout_number
      [ "계좌번호:", "은행:", "예금주:", "000-00-000000", "테스트예금주" ].each do |value|
        assert_not_includes response.body, value
      end
    end
  end

  test "결제 완료 주문만 있으면 결제 안내를 표시하지 않는다" do
    with_payout_env("PAYOUT_BANK" => "테스트은행", "PAYOUT_ACCOUNT" => "000-00-000000", "PAYOUT_HOLDER" => "테스트예금주") do
      @order.update!(status: "paid")
      verify_order
      assert_select "#payment-instruction", count: 0
    end
  end

  private

  def verify_order(checkout_number: @order.checkout_number, phone_suffix: "9876")
    post orders_lookup_path, params: { checkout_number: checkout_number, phone_suffix: phone_suffix }
    assert_redirected_to customer_order_path(@order.checkout_number)
    follow_redirect!
    assert_response :success
  end

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
