require "test_helper"

class OperatorFeedbacksControllerTest < ActionDispatch::IntegrationTest
  test "operator saves five characters and trusted attribution" do
    sign_in
    assert_no_difference "Feedback.count" do
      post operator_feedbacks_path, params: { feedback: { body: "가" * 4, kind: "stuck" } }, as: :json
    end
    assert_response :unprocessable_entity
    assert_difference "Feedback.count" do
      post operator_feedbacks_path, params: { feedback: {
        body: "가" * 5, kind: "stuck", manual_chapter: 0, page_url: "https://example.com/dashboard?q=test",
        user_id: users(:other).id, account_id: accounts(:other).id, source: "customer_web"
      } }, as: :json
    end
    assert_response :created
    assert_equal "의견을 받았어요", response.parsed_body["message"]
    feedback = Feedback.last
    assert_equal users(:one), feedback.user
    assert_equal accounts(:jieum), feedback.account
    assert_equal "operator", feedback.source
    assert_equal "stuck", feedback.kind
    assert_equal 0, feedback.manual_chapter
    assert_equal "https://example.com/dashboard?q=test", feedback.page_url
  end

  test "chapter is optional and must be in the manual" do
    sign_in
    post operator_feedbacks_path, params: { feedback: { body: "가" * 5, manual_chapter: 12 } }, as: :json
    assert_response :unprocessable_entity
    post operator_feedbacks_path, params: { feedback: { body: "가" * 5, manual_chapter: "" } }, as: :json
    assert_response :created
    assert_nil Feedback.last.manual_chapter
  end

  test "only admins see panel and can submit" do
    get root_path
    assert_select "#operator-feedback", count: 0
    assert_no_difference "Feedback.count" do
      post operator_feedbacks_path, params: { feedback: { body: "가" * 5 } }
    end
    assert_redirected_to login_path
    post login_path, params: { email: users(:other).email, password: "TestPassword!2026" }
    assert_redirected_to workspace_path
    get workspace_path
    assert_select "#operator-feedback", count: 0
    assert_no_difference "Feedback.count" do
      post operator_feedbacks_path, params: { feedback: { body: "가" * 5 } }
    end
    assert_redirected_to workspace_path
    delete logout_path
    sign_in
    get root_path
    assert_select "#operator-feedback-toggle", text: "의견 보내기"
    assert_select "#operator-feedback-panel[hidden]"
  end
end
