class TrendsController < ApplicationController
  def index
    @api_configured = Trends::DatalabApiClient.new.configured?
    recommender = Trends::CharacterRecommender.new
    @recommendations = Character.order(:age_band, :id).map { |character| [ character, recommender.call(character) ] }
    @recommendations, without_data = @recommendations.partition { |_, rows| rows.any? }
    @characters_without_data = without_data.map(&:first)
    @snapshots = TrendSnapshot.order(period_start: :desc, imported_at: :desc).to_a.group_by(&:series_name).transform_values(&:first)
  end

  def create
    unless params[:file].respond_to?(:read)
      return redirect_to trends_path, alert: "업로드할 CSV 파일을 선택하세요."
    end
    result = Trends::DatalabCsvImporter.new.call(params[:file], age_band: params[:age_band], note: params[:note])
    redirect_to trends_path, notice: import_notice(result)
  rescue Trends::DatalabCsvImporter::Error => e
    redirect_to trends_path, alert: e.message
  end

  private

  # flash 는 쿠키 세션에 저장되므로 건너뛴 줄 사유는 앞 5건만 보여준다.
  def import_notice(result)
    message = "생성 #{result.created}건, 갱신 #{result.updated}건."
    return message if result.skipped.empty?

    shown = result.skipped.first(5).join(" ")
    rest = result.skipped.size - 5
    "#{message} 건너뜀 #{result.skipped.size}건: #{shown}#{rest.positive? ? " 외 #{rest}건" : ""}"
  end
end
