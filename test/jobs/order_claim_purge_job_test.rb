require "test_helper"

class OrderClaimPurgeJobTest < ActiveJob::TestCase
  test "종료된 클레임만 설정 기간 경과 후 파기하고 경계 직전과 진행 중 기록은 보존한다" do
    original = Rails.configuration.x.order_claim_retention_years
    Rails.configuration.x.order_claim_retention_years = 2
    freeze_time do
      cutoff = 2.years.ago
      expired = %w[completed rejected].map { |status| create_claim(status, cutoff - 1.second) }
      retained = %w[completed rejected].flat_map do |status|
        [ create_claim(status, cutoff), create_claim(status, cutoff + 1.second), create_claim(status, nil) ]
      end
      ongoing = %w[requested approved].map do |status|
        [ create_claim("completed", cutoff - 1.year), status ]
      end
      ongoing.each do |claim, status|
        claim.update_columns(status: status)
        retained << claim
      end
      assert_equal 2, OrderClaimPurgeJob.perform_now
      expired.each { |claim| assert_not OrderClaim.exists?(claim.id) }
      retained.each { |claim| assert OrderClaim.exists?(claim.id) }
    end
  ensure
    Rails.configuration.x.order_claim_retention_years = original
  end

  private

  def create_claim(status, processed_at)
    orders(:one).order_claims.create!(kind: "cancel", status: status, reason_code: "other",
      requester: "guest", processed_at: processed_at)
  end
end
