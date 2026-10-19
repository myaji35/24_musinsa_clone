require "test_helper"
require "minitest/mock"

class CampaignTest < ActiveSupport::TestCase
  setup do
    @campaign = campaigns(:one)
    @campaign.update!(target_segment: nil)
  end

  test "성공 시 전용 이력을 저장하고 Slack 요약을 한 번 보낸다" do
    summaries = []
    Notifications::SlackNotifier.stub(:call, ->(**args) { summaries << args }) do
      assert_no_difference "Notification.count" do
        @campaign.send_campaign!
      end
    end

    assert_equal "sent", @campaign.reload.status
    assert_equal 2, @campaign.target_count
    assert_equal 2, @campaign.sent_count
    assert_not_nil @campaign.sent_at
    assert_equal 1, summaries.size
    assert_equal [ "sent" ], @campaign.campaign_deliveries.distinct.pluck(:status)
    @campaign.campaign_deliveries.each do |delivery|
      assert_equal "internal", delivery.channel
      assert_equal @campaign.message_template, delivery.message
      assert_not_nil delivery.sent_at
      assert_nil delivery.failure_reason
    end
  end

  test "개인화 메시지 일부 실패는 고객별로 기록하고 계속한다" do
    @campaign.update!(message_template: nil)
    calls = 0
    generator = lambda do |*_args|
      calls += 1
      raise ArgumentError, "메시지 생성 실패" if calls == 1
      { text: "개인화 추천" }
    end
    deliver_with(generator)

    assert_equal "partially_failed", @campaign.reload.status
    assert_equal 2, @campaign.target_count
    assert_equal 1, @campaign.sent_count
    assert_equal "ArgumentError: 메시지 생성 실패", @campaign.campaign_deliveries.find_by!(status: "failed").failure_reason
    assert_equal "개인화 추천", @campaign.campaign_deliveries.find_by!(status: "sent").message
  end

  test "전부 실패하면 사유를 500자 이내로 기록한다" do
    @campaign.update!(message_template: nil)
    deliver_with(->(*_args) { raise RuntimeError, "실패" * 500 })

    assert_equal "failed", @campaign.reload.status
    assert_equal 0, @campaign.sent_count
    assert_equal 2, @campaign.target_count
    assert_nil @campaign.sent_at
    @campaign.campaign_deliveries.each do |delivery|
      assert_equal "failed", delivery.status
      assert delivery.failure_reason.start_with?("RuntimeError: ")
      assert_operator delivery.failure_reason.length, :<=, 500
    end
  end

  test "대상이 없으면 캠페인에 실패 사유를 남긴다" do
    @campaign.update!(target_segment: { "zip_prefix" => "999" })
    Notifications::SlackNotifier.stub(:call, nil) { @campaign.send_campaign! }

    assert_equal "failed", @campaign.reload.status
    assert_equal "발송 대상 고객이 없습니다.", @campaign.failure_reason
    assert_equal 0, @campaign.target_count
    assert_equal 0, @campaign.sent_count
    assert_empty @campaign.campaign_deliveries
  end

  test "재실행은 성공한 고객을 건너뛰고 실패한 고객만 재시도한다" do
    @campaign.update!(message_template: nil)
    calls = 0
    deliver_with(lambda do |*_args|
      calls += 1
      raise "일시 실패" if calls == 1
      { text: "첫 메시지" }
    end)
    original = @campaign.campaign_deliveries.find_by!(status: "sent")
    original_time = original.sent_at
    retries = 0
    assert_no_difference "CampaignDelivery.count" do
      deliver_with(lambda do |*_args|
        retries += 1
        { text: "재시도 메시지" }
      end)
    end
    assert_equal 1, retries
    assert_equal "sent", @campaign.reload.status
    assert_equal 2, @campaign.sent_count
    assert_equal "첫 메시지", original.reload.message
    assert_equal original_time, original.sent_at
    assert @campaign.campaign_deliveries.all? { |delivery| delivery.failure_reason.nil? }
    deliver_with(->(*_args) { flunk "성공 고객은 다시 생성하지 않아야 함" })
    assert_equal 2, @campaign.campaign_deliveries.count
  end

  test "Slack 예외는 발송 결과에 영향을 주지 않는다" do
    Notifications::SlackNotifier.stub(:call, ->(**_args) { raise "Slack 장애" }) do
      @campaign.send_campaign!
    end
    assert_equal "sent", @campaign.reload.status
    assert_equal 2, @campaign.sent_count
  end

  test "캠페인을 삭제하면 발송 이력도 삭제된다" do
    Notifications::SlackNotifier.stub(:call, nil) { @campaign.send_campaign! }
    assert_difference "CampaignDelivery.count", -2 do
      @campaign.destroy!
    end
  end

  private

  def deliver_with(generator)
    Notifications::SlackNotifier.stub(:call, nil) do
      ClaudeBot::MessageGenerator.stub(:generate_marketing_message, generator) do
        @campaign.send_campaign!
      end
    end
  end
end
