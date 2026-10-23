require "test_helper"

class LayoutLinksTest < ActionDispatch::IntegrationTest
  test "게스트 홈에 모바일 공용 메뉴를 표시하고 관리자 메뉴를 숨긴다" do
    get root_path

    assert_response :success
    assert_mobile_menu(root_path)
    assert_select 'nav [aria-label="모바일 관리자 메뉴"]', count: 0
    assert_select 'nav [aria-label="데스크톱 메뉴"].hidden.md\\:flex', count: 1
  end

  test "로그인하면 모바일 공용 메뉴 아래에 관리자 메뉴를 표시한다" do
    sign_in
    get root_path

    assert_response :success
    assert_mobile_menu(root_path)
    assert_select 'nav [aria-label="모바일 메뉴"] + [aria-label="모바일 관리자 메뉴"].md\\:hidden', count: 1
  end

  test "모바일 메뉴는 상품과 매거진의 현재 페이지를 표시한다" do
    [ products_path, magazine_path ].each do |path|
      get path

      assert_response :success
      assert_mobile_menu(path)
    end
  end

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

  private

  def assert_mobile_menu(current_path)
    assert_select 'nav [aria-label="모바일 메뉴"].md\\:hidden', count: 1 do
      assert_select "a", count: 3
      { root_path => "랭킹", products_path => "상품", magazine_path => "매거진" }.each do |path, label|
        assert_select "a[href=?]", path, text: label, count: 1
      end
      assert_select 'a[aria-current="page"]', count: 1
      assert_select 'a[aria-current="page"].underline[href=?]', current_path, count: 1
      assert_select "a:not([aria-current]).underline", count: 0
    end
  end
end
