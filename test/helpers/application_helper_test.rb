require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "시각을 서울 시간으로 표시한다" do
    assert_equal "2026-10-13 18:28", seoul_datetime(Time.utc(2026, 10, 13, 9, 28))
  end
end
