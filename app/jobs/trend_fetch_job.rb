class TrendFetchJob < ApplicationJob
  queue_as :default

  def perform
    result = Trends::DatalabApiClient.new.call
    Rails.logger.info("트렌드 수집: #{result.message} (#{result.count}건)")
  end
end
