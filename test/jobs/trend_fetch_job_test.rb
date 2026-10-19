require "test_helper"
require "minitest/mock"

class TrendFetchJobTest < ActiveJob::TestCase
  test "키가 없으면 정상 종료하고 CSV 안내를 로그로 남긴다" do
    client = Trends::DatalabApiClient.new(env: {}, http: Object.new)
    messages = []
    Rails.logger.stub(:info, ->(message) { messages << message }) do
      Trends::DatalabApiClient.stub(:new, -> { client }) { TrendFetchJob.perform_now }
    end
    assert messages.any? { |message| message.to_s.include?(Trends::DatalabApiClient::MISSING_KEYS) }
    assert_equal 0, TrendSnapshot.count
  end
end
