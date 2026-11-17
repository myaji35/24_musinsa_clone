require "test_helper"

class Admin::OrderClaimsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @claim = orders(:one).order_claims.create!(kind: "cancel", reason_code: "other",
      requester: "member", user: users(:member), detail: "취소 요청 상세")
  end

  test "운영자와 관리자는 목록과 상세에 접근한다" do
    [ :operator, :one ].each do |role|
      sign_in(users(role))
      get admin_order_claims_path
      assert_response :success
      assert_select "table a[href=?]", admin_order_claim_path(@claim)
      assert_select "ul.lg\\:hidden a[href=?]", admin_order_claim_path(@claim)
      get admin_order_claim_path(@claim)
      assert_response :success
      assert_select "dd", text: "회원"
      assert_select "dd", text: "취소 요청 상세"
      assert_not_includes response.body, users(:member).email
      assert_not_includes response.body, users(:member).name
      assert_select "textarea[name=note][required]"
      assert_select "form[action=?]", approve_admin_order_claim_path(@claim)
      assert_select "form[action=?]", complete_admin_order_claim_path(@claim), count: 0
      delete logout_path
    end
  end

  test "회원은 루트 손님은 로그인으로 이동하며 모든 처리 액션에 접근할 수 없다" do
    [ nil, :member ].each do |role|
      post login_path, params: { email: users(role).email, password: "TestPassword!2026" } if role
      destination = role ? root_path : login_path
      [ admin_order_claims_path, admin_order_claim_path(@claim) ].each do |path|
        get path
        assert_redirected_to destination
      end
      [ approve_admin_order_claim_path(@claim), reject_admin_order_claim_path(@claim), complete_admin_order_claim_path(@claim) ].each do |path|
        patch path, params: { note: "거절 사유" }
        assert_redirected_to destination
        assert_equal "requested", @claim.reload.status
      end
    end
  end

  test "운영자는 승인 후 환불 완료하고 상세로 돌아간다" do
    sign_in(users(:operator))
    patch approve_admin_order_claim_path(@claim)
    assert_redirected_to admin_order_claim_path(@claim)
    assert_equal "approved", @claim.reload.status
    assert_equal "cancelled", @claim.order.reload.status
    assert flash[:notice].present?
    get admin_order_claim_path(@claim)
    assert_select "button", text: "환불 완료"
    assert_select "textarea", count: 0
    patch complete_admin_order_claim_path(@claim)
    assert_redirected_to admin_order_claim_path(@claim)
    assert_equal "completed", @claim.reload.status
    assert_not_nil @claim.refunded_at
    assert_equal users(:operator), @claim.processed_by
    get admin_order_claim_path(@claim)
    assert_select "form[action=?]", complete_admin_order_claim_path(@claim), count: 0
  end

  test "관리자는 거절 사유를 입력해야 거절할 수 있다" do
    sign_in
    patch reject_admin_order_claim_path(@claim)
    assert_redirected_to admin_order_claim_path(@claim)
    assert_equal "거절 사유를 입력해 주세요.", flash[:alert]
    assert_equal "requested", @claim.reload.status
    patch reject_admin_order_claim_path(@claim), params: { note: "접수 조건 불충족" }
    assert_redirected_to admin_order_claim_path(@claim)
    assert_equal "rejected", @claim.reload.status
    assert_equal "접수 조건 불충족", @claim.admin_note
    assert flash[:notice].present?
  end

  test "승인 전 완료 요청은 실패한다" do
    sign_in
    patch complete_admin_order_claim_path(@claim)
    assert_redirected_to admin_order_claim_path(@claim)
    assert flash[:alert].present?
    assert_equal "requested", @claim.reload.status
  end

  test "반품과 교환의 승인 및 완료 버튼 문구와 처리를 확인한다" do
    sign_in
    { "return" => "반품 입고·환불 완료", "exchange" => "교환 완료" }.each do |kind, label|
      claim = orders(:two).order_claims.create!(kind: kind, reason_code: "size", requester: "guest")
      patch approve_admin_order_claim_path(claim)
      assert_equal "approved", claim.reload.status
      get admin_order_claim_path(claim)
      assert_select "dd", text: "비회원"
      assert_select "button", text: label
      patch complete_admin_order_claim_path(claim)
      assert_redirected_to admin_order_claim_path(claim)
      assert_equal "completed", claim.reload.status
      assert_equal(kind == "return" ? "returned" : "delivered", claim.order.reload.status)
    orders(:two).reload.update!(status: "delivered")
    end
  end

  test "목록은 기본 진행 중이며 상태 필터와 최신순 삼십 건 페이지를 지원한다" do
    sign_in
    @claim.update!(status: "completed")
    approved = orders(:two).order_claims.create!(kind: "return", status: "approved", reason_code: "other", requester: "guest")
    get admin_order_claims_path
    assert_select "table a[href=?]", admin_order_claim_path(@claim), count: 0
    assert_select "table a[href=?]", admin_order_claim_path(approved), count: 1
    get admin_order_claims_path(status: "completed")
    assert_select "table a[href=?]", admin_order_claim_path(@claim), count: 1
    assert_select "table a[href=?]", admin_order_claim_path(approved), count: 0
    30.times do |index|
      @claim.order.order_claims.create!(kind: "cancel", status: "completed", reason_code: "other",
        requester: "guest", created_at: Time.current + index.seconds)
    end
    get admin_order_claims_path(status: "all")
    assert_select "tbody tr", count: 30
    assert_select "nav[aria-label='페이지'] a", text: "다음"
    get admin_order_claims_path(status: "all", page: 2)
    assert_select "tbody tr", count: 2
    assert_select "nav[aria-label='페이지'] a", text: "이전"
  end
end
