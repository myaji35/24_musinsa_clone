require "test_helper"

class MyClaimsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @order = orders(:one)
    @order.update!(user: users(:member))
  end

  test "손님은 요청 폼과 제출에서 로그인으로 이동한다" do
    get new_my_order_claim_path(@order)
    assert_redirected_to login_path
    assert_no_difference "OrderClaim.count" do
      post my_order_claims_path(@order), params: claim_params
    end
    assert_redirected_to login_path
  end

  test "남의 주문은 조회와 제출 모두 찾을 수 없다" do
    login_member
    other_order = orders(:two)
    get new_my_order_claim_path(other_order)
    assert_response :not_found
    assert_no_difference "OrderClaim.count" do
      post my_order_claims_path(other_order), params: claim_params
    end
    assert_response :not_found
  end

  test "본인 주문 폼을 보고 취소 요청을 접수한다" do
    login_member
    get new_my_order_claim_path(@order)
    assert_response :success
    assert_select "input[type=radio][value=cancel]"
    assert_select 'textarea[maxlength="500"]'
    assert_difference "OrderClaim.count", 1 do
      post my_order_claims_path(@order), params: claim_params
    end
    assert_redirected_to my_orders_path
    claim = @order.order_claims.last
    assert_equal users(:member), claim.user
    assert_equal "requested", claim.status
    get my_orders_path
    assert_select "p", text: "취소 접수", count: 2
  end

  test "결제 대기 주문 폼은 취소를 미리 선택한다" do
    @order.update!(status: "pending")
    login_member
    get new_my_order_claim_path(@order)
    assert_response :success
    assert_select "h1", text: "취소 요청"
    assert_select "input[type=radio][value=cancel][checked]"
    assert_select "p", text: /반품·교환은 배송 완료/, count: 0
    assert_select "a[href=?]", my_orders_path, text: "돌아가기"
  end

  test "유효하지 않은 요청은 입력값과 오류를 표시한다" do
    login_member
    post my_order_claims_path(@order), params: { order_claim: { kind: "cancel", reason_code: "invalid", detail: "상세 내용" } }
    assert_response :unprocessable_entity
    assert_select "[role=alert] li"
    assert_select "textarea", text: "상세 내용"
  end

  private

  def login_member
    post login_path, params: { email: users(:member).email, password: "TestPassword!2026" }
    assert_redirected_to root_path
  end

  def claim_params
    { order_claim: { kind: "cancel", reason_code: "changed_mind", detail: "취소 부탁드립니다" } }
  end
end
