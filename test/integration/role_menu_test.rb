require "test_helper"

class RoleMenuTest < ActionDispatch::IntegrationTest
  test "손님에게 로그인과 회원가입을 표시하고 관리 메뉴는 숨긴다" do
    get root_path
    assert_response :success
    assert_select "nav[aria-label='계정 메뉴']" do
      assert_select "a[href=?]", login_path, text: "로그인"
      assert_select "a[href=?]", join_path, text: "회원가입"
    end
    assert_select "li[class='md:hidden'] a[href=?]", login_path, text: "로그인"
    assert_select "li[class='md:hidden'] a[href=?]", join_path, text: "회원가입"
    assert_no_management_menu
  end

  test "회원에게 내 정보를 표시하고 워크스페이스와 관리 메뉴는 숨긴다" do
    login_as(:member)
    get root_path
    assert_response :success
    assert_select "a[href=?]", my_path, text: "내 정보", count: 2
    assert_select "li[class='md:hidden'] form[action=?]", logout_path do
      assert_select "button", text: "로그아웃"
    end
    assert_select "a[href=?]", workspace_path, count: 0
    assert_no_management_menu
  end

  test "운영자에게 운영 메뉴를 표시하고 관리자 전용 메뉴는 숨긴다" do
    login_as(:operator)
    get root_path
    assert_response :success
    assert_select "nav[aria-label='관리 메뉴']" do
      assert_select "a[href=?]", inventory_scan_path, text: "재고관리"
      assert_select "a[href=?]", purchase_orders_path, text: "발주"
      [ kpi_path, admin_users_path, sales_path, trends_path, product_analyses_path ].each do |path|
        assert_select "a[href=?]", path, count: 0
      end
    end
    assert_select "div[aria-label='모바일 관리자 메뉴']" do
      assert_select "a[href=?]", inventory_scan_path
      assert_select "a[href=?]", admin_users_path, count: 0
    end
  end

  test "관리자에게 사용자 관리와 경영 메뉴를 표시한다" do
    login_as(:one)
    get root_path
    assert_response :success
    assert_select "nav[aria-label='관리 메뉴']" do
      assert_select "a[href=?]", kpi_path, text: "KPI"
      assert_select "a[href=?]", admin_users_path, text: "사용자 관리"
    end
    assert_select "div[aria-label='모바일 관리자 메뉴'] a[href=?]", admin_users_path
  end

  test "입점 업체 사용자에게 워크스페이스를 표시하고 관리 메뉴는 숨긴다" do
    login_as(:other)
    get root_path
    assert_response :success
    assert_select "nav[aria-label='계정 메뉴'] a[href=?]", workspace_path, text: "내 워크스페이스"
    assert_no_management_menu
  end

  test "상품 수정 화면에서 운영자는 삭제 버튼을 볼 수 없고 관리자는 볼 수 있다" do
    login_as(:operator)
    get edit_product_path(products(:one))
    assert_response :success
    assert_select "button", text: "삭제", count: 0
    delete logout_path

    login_as(:one)
    get edit_product_path(products(:one))
    assert_response :success
    assert_select "form[action=?]", product_path(products(:one)) do
      assert_select "input[name='_method'][value='delete']"
      assert_select "button", text: "삭제"
    end
  end

  private

  def login_as(fixture)
    post login_path, params: { email: users(fixture).email, password: "TestPassword!2026" }
  end

  def assert_no_management_menu
    assert_select "nav[aria-label='관리 메뉴']", count: 0
    assert_select "div[aria-label='모바일 관리자 메뉴']", count: 0
  end
end
