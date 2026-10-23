require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  test "permanently redirects search query to home search" do
    get search_url, params: { q: "셔츠" }

    assert_response :moved_permanently
    assert_redirected_to "/?q=%EC%85%94%EC%B8%A0"
    assert_not_includes response.body, "Find me in"
  end

  test "permanently redirects search without query to home" do
    get search_url

    assert_response :moved_permanently
    assert_redirected_to "/"
    assert_not_includes response.body, "Find me in"
  end

  test "permanently redirects blank search query to home" do
    get search_url, params: { q: " " }

    assert_response :moved_permanently
    assert_redirected_to "/"
    assert_not_includes response.body, "Find me in"
  end
end
