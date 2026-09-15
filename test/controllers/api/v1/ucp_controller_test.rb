require "test_helper"

class Api::V1::UcpControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
  end

  test "API 키가 미설정이면 서비스 불가 오류를 반환한다" do
    with_ucp_api_key(nil) do
      get "/api/v1/ucp/products"

      assert_response :service_unavailable
      assert_equal "error", response.parsed_body["status"]
    end
  end

  test "API 키가 설정되어도 헤더가 없으면 인증을 거부한다" do
    with_ucp_api_key("test-key") do
      get "/api/v1/ucp/products"

      assert_response :unauthorized
    end
  end

  test "잘못된 API 키로 접근하면 인증을 거부한다" do
    with_ucp_api_key("test-key") do
      get "/api/v1/ucp/products", headers: { "X-API-Key" => "wrong-key" }

      assert_response :unauthorized
    end
  end

  test "올바른 API 키는 헤더와 파라미터 모두 접근을 허용한다" do
    with_ucp_api_key("test-key") do
      get "/api/v1/ucp/products", headers: { "X-API-Key" => "test-key" }

      assert_response :ok
      assert_equal "success", response.parsed_body["status"]

      get "/api/v1/ucp/products", params: { api_key: "test-key" }

      assert_response :ok
      assert_equal "success", response.parsed_body["status"]
    end
  end

  private

  def with_ucp_api_key(key)
    original_key = ENV["UCP_API_KEY"]
    key.nil? ? ENV.delete("UCP_API_KEY") : ENV["UCP_API_KEY"] = key
    yield
  ensure
    original_key.nil? ? ENV.delete("UCP_API_KEY") : ENV["UCP_API_KEY"] = original_key
  end
end
