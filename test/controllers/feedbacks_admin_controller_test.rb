require "test_helper"

class FeedbacksAdminControllerTest < ActionDispatch::IntegrationTest
  setup do
    @operator = Feedback.create!(account: accounts(:jieum), user: users(:one), source: "operator", kind: "stuck", body: "막히는 화면입니다", manual_chapter: 0, page_url: "/dashboard")
    @customer = Feedback.create!(account: accounts(:jieum), body: "고객이 보내는 의견입니다")
    @partner = Feedback.create!(account: accounts(:jieum), source: "partner", body: "파트너가 보내는 의견입니다", status: "in_review")
    @foreign = Feedback.create!(account: accounts(:other), user: users(:other), source: "operator", body: "다른 계정의 비공개 의견", manual_chapter: 0)
  end

  test "admin inbox and badge are scoped and show existing customers" do
    sign_in
    get feedbacks_admin_index_path
    assert_response :ok
    [ @operator, @customer, @partner ].each { |feedback| assert_select "tr[data-feedback-id='#{feedback.id}']" }
    assert_select "tr[data-feedback-id='#{@foreign.id}']", count: 0
    assert_select "a", text: "의견함 (2)", count: 2
    assert_includes response.body, "김민수"
    assert_includes response.body, "고객"
    assert_select "a[href='/dashboard']"
    get feedbacks_admin_path(@operator)
    assert_response :ok
    assert_includes response.body, @operator.body
  end

  test "all filters and combined filters" do
    sign_in
    [ { status: "new" }, { kind: "stuck" }, { source: "운영자" }, { manual_chapter: "0" },
      { status: "new", kind: "stuck", source: "운영자", manual_chapter: "0" } ].each do |filter|
      get feedbacks_admin_index_path, params: filter
      assert_select "tr[data-feedback-id='#{@operator.id}']"
      assert_select "tr[data-feedback-id='#{@partner.id}']", count: 0
      assert_select "tr[data-feedback-id='#{@foreign.id}']", count: 0
    end
    get feedbacks_admin_index_path, params: { source: "고객" }
    assert_select "tr[data-feedback-id='#{@customer.id}']"
    assert_select "tr[data-feedback-id='#{@operator.id}']", count: 0
    get feedbacks_admin_index_path, params: { source: "파트너" }
    assert_select "tr[data-feedback-id='#{@partner.id}']"
    assert_select "tr[data-feedback-id='#{@customer.id}']", count: 0
  end

  test "status and note updates set and clear answered time without changing attribution" do
    sign_in
    patch feedbacks_admin_path(@operator), params: { feedback: { status: "answered", handling_note: "화면 안내 수정", account_id: accounts(:other).id, user_id: users(:other).id } }
    assert_redirected_to feedbacks_admin_path(@operator)
    assert_equal "answered", @operator.reload.status
    assert_equal "화면 안내 수정", @operator.handling_note
    assert_not_nil @operator.answered_at
    assert_equal accounts(:jieum), @operator.account
    assert_equal users(:one), @operator.user
    patch feedbacks_admin_path(@operator), params: { feedback: { status: "in_review" } }
    assert_nil @operator.reload.answered_at
    patch feedbacks_admin_path(@operator), params: { feedback: { status: "closed" } }
    assert_not_nil @operator.reload.answered_at
    patch feedbacks_admin_path(@operator), params: { feedback: { status: "invalid" } }
    assert_response :unprocessable_entity
    assert_equal "closed", @operator.reload.status
  end

  test "cannot read or update another tenant" do
    sign_in
    get feedbacks_admin_path(@foreign)
    assert_response :not_found
    patch feedbacks_admin_path(@foreign), params: { feedback: { status: "closed" } }
    assert_response :not_found
    assert_equal "new", @foreign.reload.status
  end

  test "all inbox endpoints require admin" do
    [ nil, users(:other) ].each do |user|
      post login_path, params: { email: user.email, password: "TestPassword!2026" } if user
      get feedbacks_admin_index_path
      assert_redirected_to(user ? workspace_path : login_path)
      get feedbacks_admin_path(@operator)
      assert_redirected_to(user ? workspace_path : login_path)
      patch feedbacks_admin_path(@operator), params: { feedback: { status: "closed" } }
      assert_redirected_to(user ? workspace_path : login_path)
      assert_equal "new", @operator.reload.status
    end
  end

  test "unsafe page URLs are displayed without active links" do
    sign_in
    [ "javascript:alert(1)", "//evil.example", "/\\evil.example", "https://example.com/path" ].each do |url|
      @operator.update!(page_url: url)
      get feedbacks_admin_path(@operator)
      assert_select "a[href=?]", url, count: url.start_with?("https:") ? 1 : 0
    end
  end
end
