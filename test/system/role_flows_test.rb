require "application_system_test_case"

class RoleFlowsTest < ApplicationSystemTestCase
  test "손님이 가입하고 상품을 주문한 뒤 내 주문을 확인한다" do
    visit join_path
    fill_in "이름", with: "가입 테스트"
    fill_in "이메일", with: "role-flow-#{SecureRandom.hex(6)}@example.com"
    fill_in "비밀번호", with: "TestPassword!2026", exact: true
    fill_in "비밀번호 확인", with: "TestPassword!2026"
    check "[필수] 이용약관에 동의합니다"
    check "[필수] 개인정보 수집·이용에 동의합니다"
    check "[필수] 만 14세 이상입니다"
    click_button "회원가입"
    assert_current_path root_path
    within('nav[aria-label="계정 메뉴"]') { assert_text "가입 테스트" }

    product = products(:one) # status 기본값 published, variants(:one)의 재고 5
    variant = variants(:one)
    assert product.published?
    assert_operator variant.stock, :>, 0
    visit product_path(product)
    click_button "장바구니", exact: true
    assert_current_path cart_path
    assert_text product.name
    click_link "비회원 주문하기"
    assert_current_path new_checkout_path
    fill_in "받는 분", with: "테스트"
    fill_in "휴대폰", with: "010-0000-0000"
    fill_in "우편번호", with: "06000"
    fill_in "주소", with: "서울 테스트로 1", exact: true
    check "checkout_privacy_consent"
    click_button "주문하기", exact: true
    assert_selector "h1", text: "주문 내역"
    assert_text "결제 대기"
    checkout_number = URI.parse(page.current_url).path.split("/").last
    order = Order.find_by!(checkout_number: checkout_number, variant: variant)
    visit my_orders_path
    within("tbody tr", text: order.order_number) { assert_text "결제 대기" }
  end

  test "회원에게 관리 메뉴가 없고 재고 화면 접근이 거부된다" do
    sign_in_via_form users(:member)
    assert_current_path root_path
    assert_no_selector 'nav[aria-label="관리 메뉴"]', visible: :all
    visit inventory_scan_path
    assert_current_path root_path
    assert_text "접근 권한이 없습니다."
  end

  test "운영자는 재고 메뉴만 보고 관리자 KPI 접근이 거부된다" do
    sign_in_via_form users(:operator)
    within('nav[aria-label="관리 메뉴"]') do
      assert_link "재고관리", href: inventory_scan_path
      assert_no_link "KPI", visible: :all
      assert_no_link "사용자 관리", visible: :all
    end
    visit kpi_path
    assert_current_path inventory_scan_path
    assert_text "이 화면은 관리자 전용입니다"
  end

  test "관리자가 회원의 역할을 운영자로 변경한다" do
    sign_in_via_form users(:one)
    within('nav[aria-label="관리 메뉴"]') { click_link "사용자 관리" }
    assert_current_path admin_users_path
    member = users(:member)
    within("tbody tr", text: member.email) do
      find('select[aria-label="최회원 역할"]').select("운영자")
      click_button "변경"
    end
    assert_text "역할을 변경했습니다."
    assert member.reload.operator?
  end

  test "손님이 발주 화면에서 로그인하면 원래 화면으로 돌아온다" do
    visit purchase_orders_path
    assert_current_path login_path
    sign_in_via_form users(:one)
    assert_current_path purchase_orders_path
  end

  private

  def sign_in_via_form(user)
    visit login_path
    fill_in "이메일", with: user.email
    fill_in "비밀번호", with: "TestPassword!2026", exact: true
    click_button "로그인", exact: true
    assert_no_current_path login_path
  end
end
