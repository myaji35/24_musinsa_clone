require "test_helper"

class LayoutLinksTest < ActionDispatch::IntegrationTest
  [ "/", "/returns" ].each do |path|
    test "#{path}의 레이아웃에는 죽은 링크가 없고 비회원 주문조회를 제공한다" do
      get path

      assert_response :success
      assert_select '[href="#"]', count: 0
      assert_select "footer div:has(> h4)", text: /HELP/ do
        assert_select "li", count: 2
        assert_select "a[href=?]", orders_lookup_path, text: "비회원 주문조회", count: 1
        assert_select "a[href=?]", returns_policy_path, text: "배송·반품 안내", count: 1
      end
      assert_select "footer div:has(> h4)", text: /POLICY/ do
        assert_select "li", count: 2
        assert_select "a", count: 0
        assert_select 'span[aria-disabled="true"].font-normal.text-gray-600', count: 2
      end
      assert_not_includes response.body, "Solid Queue"
      assert_select "a", text: "회원가입", count: 0
      assert_select "footer a[href=?]", returns_policy_path, text: "배송·반품 안내", count: 1
      assert_select 'footer span[aria-disabled="true"]', text: "개인정보처리방침 (준비 중)", count: 1
      assert_select 'footer span[aria-disabled="true"]', text: "이용약관 (준비 중)", count: 1
      assert_select "footer a", text: /개인정보처리방침|이용약관/, count: 0
    end
  end
end
