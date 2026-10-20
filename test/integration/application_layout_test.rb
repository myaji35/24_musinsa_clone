require "test_helper"

class ApplicationLayoutTest < ActionDispatch::IntegrationTest
  test "게스트에게는 두 메뉴의 관리자 링크를 표시하지 않는다" do
    get root_path

    assert_response :success
    admin_paths.each do |path|
      assert_select "nav a[href=?]", path, count: 0
    end
    assert_select 'nav [aria-label="모바일 관리자 메뉴"]', count: 0
    assert_select 'nav a[href="/products"]', text: "상품"
  end

  test "로그인하면 데스크톱과 모바일 메뉴에 관리자 링크를 표시한다" do
    sign_in
    get root_path

    assert_response :success
    [ "데스크톱 메뉴", "모바일 관리자 메뉴" ].each do |label|
      assert_select "nav [aria-label=?]", label do
        admin_paths.each do |path|
          assert_select "a[href=?]", path, count: 1
        end
      end
    end
  end

  test "로그인 알림은 재고 화면에 한 번 표시하고 다음 요청에서 사라진다" do
    sign_in
    follow_redirect!

    assert_select '[role="status"]', text: "로그인되었습니다.", count: 1
    assert_equal 1, response.body.scan("로그인되었습니다.").size
    get inventory_scan_path
    assert_select '[role="status"]', count: 0
  end

  test "로그아웃 알림은 공개 화면에도 표시한다" do
    sign_in
    delete logout_path
    follow_redirect!

    assert_select '[role="status"]', text: "로그아웃되었습니다.", count: 1
  end

  test "로그인 실패 경고는 한 번 표시하고 다음 요청에서 사라진다" do
    post login_path, params: { email: users(:one).email, password: "wrong" }

    assert_response :unprocessable_entity
    assert_select '[role="alert"]', text: "이메일 또는 비밀번호가 올바르지 않습니다.", count: 1
    assert_equal 1, response.body.scan("이메일 또는 비밀번호가 올바르지 않습니다.").size
    get login_path
    assert_select '[role="alert"]', count: 0
  end

  test "홈은 한국어 문서와 이름이 있는 상품 찜 버튼을 표시한다" do
    get root_path

    assert_select "html[lang=ko]", count: 1
    assert_select 'button[data-wishlist-target="button"][aria-label="찜하기"][aria-pressed="false"]', minimum: 1
  end

  private

  def admin_paths
    [ inventory_scan_path, dashboard_index_path, suppliers_path, purchase_orders_path,
      supplier_imports_path, product_analyses_path, kpi_path, trends_path ]
  end
end
