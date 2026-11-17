require "test_helper"

class AccessLogTest < ActiveSupport::TestCase
  test "이메일은 로컬 부분 첫 글자와 도메인만 남긴다" do
    assert_equal "a***@jieun.test", AccessLog.mask_email("admin@jieun.test")
    assert_equal "a***@jieun.test", AccessLog.mask_email("a@jieun.test")
    assert_equal "김***@jieun.test", AccessLog.mask_email("김직원@jieun.test")
  end
end
