require "test_helper"

class SalesControllerTest < ActionDispatch::IntegrationTest
  test "비로그인은 로그인으로 이동한다" do
    get sales_path
    assert_redirected_to login_path
  end

  test "기간 집계는 취소를 제외하고 부족 옵션을 표시한다" do
    sign_in
    travel_to Time.zone.local(2026, 11, 6, 10) do
      Order.update_all(status: "cancelled")
      template = orders(:one)
      [ [ 0, 2 ], [ 6, 3 ], [ 29, 4 ], [ 31, 8 ] ].each do |days, quantity|
        Order.create!(anony_customer: template.anony_customer, product: template.product,
                      variant: template.variant, quantity: quantity, total_price: quantity * 1000,
                      status: "paid", created_at: days.days.ago)
      end
      { "today" => 2, "7" => 5, "30" => 9 }.each do |period, quantity|
        get sales_path, params: { period: period }
        assert_response :success
        assert_select "tbody tr td:nth-child(3)", text: "#{quantity}개"
        assert_select "span", text: "부족"
        assert_select "span", text: "품절"
      end
      get sales_path, params: { period: "custom", from: "2026-10-31", to: "2026-10-31" }
      assert_select "tbody tr td:nth-child(3)", text: "3개"
      get sales_path, params: { period: "custom", from: "bad", to: "bad" }
      assert_response :success
      assert_includes response.body, "기간을 올바르게 선택해 주세요"
    end
  end
end
