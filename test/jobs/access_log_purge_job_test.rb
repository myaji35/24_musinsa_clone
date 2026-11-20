require "test_helper"

class AccessLogPurgeJobTest < ActiveJob::TestCase
  test "설정한 보관 기간보다 오래된 기록만 파기하고 경계와 직전 기록은 남긴다" do
    original = Rails.configuration.x.access_log_retention_days
    Rails.configuration.x.access_log_retention_days = 30
    freeze_time do
      cutoff = 30.days.ago
      expired, boundary, recent = [ cutoff - 1.second, cutoff, cutoff + 1.second ].map do |time|
        AccessLog.create!(screen: "주문 관리", action: "index", created_at: time)
      end
      assert_equal 1, AccessLogPurgeJob.perform_now
      assert_not AccessLog.exists?(expired.id)
      assert AccessLog.exists?(boundary.id)
      assert AccessLog.exists?(recent.id)
    end
  ensure
    Rails.configuration.x.access_log_retention_days = original
  end
end
