require "test_helper"

class DashboardRedirectIss104Test < ActionDispatch::IntegrationTest
  test "dashboard redirects to the existing index route" do
    assert_equal "/dashboard/index", dashboard_index_path

    get "/dashboard"

    assert_response :moved_permanently
    assert_redirected_to dashboard_index_url
  end

  test "dashboard redirect preserves the original query string" do
    query = "period=7&tag=casual%20wear&tag=minimal&filter%5Bregion%5D=060"

    get "/dashboard?#{query}"

    assert_response :moved_permanently
    assert_redirected_to "#{dashboard_index_url}?#{query}"
  end
end
