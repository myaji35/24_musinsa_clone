require "test_helper"

class MyControllerTest < ActionDispatch::IntegrationTest
  test "손님은 로그인 후 내 정보로 복귀한다" do
    get my_path
    assert_redirected_to login_path
    assert_equal "로그인이 필요합니다.", flash[:alert]
    assert_equal my_path, session[:return_to]

    post login_path, params: { email: users(:member).email, password: "TestPassword!2026" }
    assert_redirected_to my_path
    follow_redirect!
    assert_response :success
  end

  test "회원과 운영자와 관리자 모두 내 정보와 한국어 역할을 확인한다" do
    { member: "일반 회원", operator: "운영자", one: "관리자" }.each do |fixture, label|
      user = users(fixture)
      post login_path, params: { email: user.email, password: "TestPassword!2026" }
      get my_path
      assert_response :success
      assert_select "dd", text: user.name
      assert_select "dd", text: user.email
      assert_select "dd", text: label
      assert_select "dd", text: user.created_at.strftime("%Y-%m-%d")
      assert_select "a[href=?]", my_path, text: "내 정보"
      assert_select "a[href=?]", my_orders_path, text: "내 주문"
      assert_select "form[action=?]", logout_path
      delete logout_path
    end
  end

  test "내 주문은 빈 상태와 비회원 주문조회 링크를 표시한다" do
    post login_path, params: { email: users(:member).email, password: "TestPassword!2026" }
    get my_orders_path
    assert_response :success
    assert_select "p", text: "아직 회원으로 주문한 내역이 없습니다. 로그인 전에 한 주문은 주문조회에서 확인하세요."
    assert_select "a[href=?]", orders_lookup_path, text: "주문조회"
    assert_select "form[action=?]", logout_path
  end

  test "내 주문에는 로그인한 회원의 주문만 표시한다" do
    member = users(:member)
    other_member = User.create!(email: "member-b@example.com", name: "회원 B",
                                password: "TestPassword!2026", role: :member)
    order = orders(:one)
    order.update!(user: member)
    post login_path, params: { email: member.email, password: "TestPassword!2026" }
    get my_orders_path
    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "td", text: order.order_number
    assert_select "td", text: order.product.name
    assert_select "td", text: "#{order.variant.color} / #{order.variant.size}"
    assert_select "td", text: order.quantity.to_s
    assert_select "td", text: "₩ 39,800"
    assert_select "td", text: order.status
    assert_select "td", text: order.created_at.strftime("%Y.%m.%d")

    delete logout_path
    post login_path, params: { email: other_member.email, password: "TestPassword!2026" }
    get my_orders_path
    assert_response :success
    assert_not_includes response.body, order.order_number
    assert_select "p", text: "아직 회원으로 주문한 내역이 없습니다. 로그인 전에 한 주문은 주문조회에서 확인하세요."
  end

  test "손님은 내 주문에 접근할 때 로그인으로 이동한다" do
    get my_orders_path
    assert_redirected_to login_path
    assert_equal my_orders_path, session[:return_to]
  end
end
