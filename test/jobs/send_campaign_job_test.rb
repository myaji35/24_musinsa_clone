require "test_helper"
require "minitest/mock"

class SendCampaignJobTest < ActiveSupport::TestCase
  test "예약 시간이 지난 캠페인을 발송한다" do
    campaign = campaigns(:two)
    campaign.update!(scheduled_at: 1.minute.ago)
    Notifications::SlackNotifier.stub(:call, nil) { SendCampaignJob.perform_now }

    assert_equal "sent", campaign.reload.status
    assert_equal 1, campaign.sent_count
    assert_equal 1, campaign.campaign_deliveries.count
    assert_equal "draft", campaigns(:one).reload.status
  end

  test "예기치 못한 예외를 failed와 사유로 남기고 다음 캠페인을 처리한다" do
    failed = campaigns(:one)
    failed.update!(status: "scheduled", scheduled_at: 1.minute.ago)
    failed.define_singleton_method(:send_campaign!) { raise ArgumentError, "장애" * 500 }
    successful = campaigns(:two)
    successful.update!(scheduled_at: 1.minute.ago)

    Campaign.stub(:pending_send, [ failed, successful ]) do
      Notifications::SlackNotifier.stub(:call, nil) { SendCampaignJob.perform_now }
    end

    assert_equal "failed", failed.reload.status
    assert failed.failure_reason.start_with?("ArgumentError: ")
    assert_operator failed.failure_reason.length, :<=, 500
    assert_equal "sent", successful.reload.status
  end

  test "미래 예약은 발송하지 않는다" do
    campaign = campaigns(:two)
    campaign.update!(scheduled_at: 1.day.from_now)
    assert_no_difference "CampaignDelivery.count" do
      SendCampaignJob.perform_now
    end
    assert_equal "scheduled", campaign.reload.status
  end
end
