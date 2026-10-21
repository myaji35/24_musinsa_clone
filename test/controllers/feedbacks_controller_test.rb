require "test_helper"

class FeedbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_store = Rack::Attack.cache.store
    @previous_enabled = Rack::Attack.enabled
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.reset!
  end

  teardown do
    Rack::Attack.reset!
    Rack::Attack.cache.store = @previous_store
    Rack::Attack.enabled = @previous_enabled
  end

  test "anonymous form and product link" do
    get new_feedback_path, params: { product_id: products(:one).id, page_url: "/products/1" }
    assert_response :ok
    assert_select 'input[name="feedback[product_id]"][value=?]', products(:one).id.to_s
    assert_select 'input[name="website"][tabindex="-1"]'
  end

  test "anonymous submission stores product and thanks customer" do
    assert_difference "Feedback.count", 1 do
      post feedbacks_path, params: { feedback: { body: "상품에 대한 의견을 보냅니다.", product_id: products(:one).id } }
    end
    assert_equal products(:one), Feedback.last.product
    follow_redirect!
    assert_response :ok
    assert_includes response.body, "의견이 접수되었습니다. 소중한 의견 감사합니다."
  end

  test "honeypot succeeds without storing" do
    assert_no_difference "Feedback.count" do
      post feedbacks_path, params: { website: "spam", feedback: { body: "상품에 대한 의견을 보냅니다." } }
    end
    assert_response :ok
    assert_includes response.body, "의견이 접수되었습니다. 소중한 의견 감사합니다."
  end

  test "honeypot response looks like the normal feedback page" do
    post feedbacks_path, params: { website: "spam", feedback: { body: "상품에 대한 의견을 보냅니다." } }
    assert_select "h1", "의견 보내기"
  end

  test "unknown product id is ignored instead of failing" do
    assert_difference "Feedback.count", 1 do
      post feedbacks_path, params: { feedback: { body: "없는 상품에서 보낸 의견입니다.", product_id: 999_999_999 } }
    end
    assert_nil Feedback.last.product_id
  end

  test "invalid body renders errors" do
    assert_no_difference "Feedback.count" do
      post feedbacks_path, params: { feedback: { body: "짧음" } }
    end
    assert_response :unprocessable_entity
    assert_includes response.body, "의견은 10자 이상 적어 주세요"
  end

  test "request logging masks IP and personal feedback parameters" do
    request = ActionDispatch::Request.new(
      "REQUEST_METHOD" => "POST", "PATH_INFO" => "/feedbacks", "REMOTE_ADDR" => "192.0.2.133",
      "QUERY_STRING" => "contact_email=person@example.com"
    )
    message = Rails::Rack::Logger.new(nil).send(:started_request_message, request)
    assert_includes message, "[FILTERED]"
    assert_not_includes message, "192.0.2.133"
    assert_not_includes message, "person@example.com"
    filtered = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
      .filter("feedback" => { "body" => "person@example.com", "contact_email" => "person@example.com" })
    assert_not_includes filtered.inspect, "person@example.com"
  end

  test "sixth request from same IP is throttled" do
    5.times do
      post feedbacks_path, params: { feedback: { body: "상품에 대한 의견을 보냅니다." } }, env: { "REMOTE_ADDR" => "192.0.2.133" }
      assert_response :redirect
    end
    assert_no_difference "Feedback.count" do
      post feedbacks_path, params: { feedback: { body: "상품에 대한 의견을 보냅니다." } }, env: { "REMOTE_ADDR" => "192.0.2.133" }
    end
    assert_response :too_many_requests
    assert_includes response.body, "잠시 후 다시 시도해 주세요"
  end
end
