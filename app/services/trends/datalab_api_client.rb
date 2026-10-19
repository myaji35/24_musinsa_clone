require "net/http"

module Trends
  class DatalabApiClient
    ENDPOINT = URI("https://openapi.naver.com/v1/datalab/shopping/categories")
    MISSING_KEYS = "키 없음 — CSV 업로드를 쓰세요"
    Result = Struct.new(:status, :message, :count, keyword_init: true)

    def initialize(env: ENV, http: Net::HTTP, categories: nil)
      @env, @http = env, http
      @categories = categories || YAML.load_file(Rails.root.join("config/trend_categories.yml"))
    end

    def configured?
      @env["NAVER_DATALAB_CLIENT_ID"].present? && @env["NAVER_DATALAB_CLIENT_SECRET"].present?
    end

    def call(start_date: 8.weeks.ago.to_date.beginning_of_week, end_date: Date.current, age_band: nil)
      return Result.new(status: :skipped, message: MISSING_KEYS, count: 0) unless configured?
      categories = @categories.filter_map { |name, code| { name: name, param: Array(code) } if code.present? }
      return Result.new(status: :skipped, message: "카테고리 코드를 설정한 후 이용하세요.", count: 0) if categories.empty?
      raise ArgumentError, "지원하지 않는 연령대입니다." unless age_band.nil? || [ 20, 30, 40, 50 ].include?(age_band)
      count = 0
      categories.each_slice(3) do |batch|
        request = Net::HTTP::Post.new(ENDPOINT)
        request["X-Naver-Client-Id"] = @env["NAVER_DATALAB_CLIENT_ID"]
        request["X-Naver-Client-Secret"] = @env["NAVER_DATALAB_CLIENT_SECRET"]
        request["Content-Type"] = "application/json"
        request.body = { startDate: start_date.iso8601, endDate: end_date.iso8601, timeUnit: "week",
          category: batch, ages: age_band ? [ age_band.to_s ] : [] }.to_json
        response = @http.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, open_timeout: 10, read_timeout: 30) { |connection| connection.request(request) }
        raise "데이터랩 요청 실패 (HTTP #{response.code})" unless response.code.to_i.between?(200, 299)
        TrendSnapshot.transaction do
          JSON.parse(response.body).fetch("results").each do |series|
            series.fetch("data").each do |point|
              TrendSnapshot.store!(source: "datalab_api", series_name: series.fetch("title"),
                period_start: Date.iso8601(point.fetch("period")).beginning_of_week(:monday), ratio: point.fetch("ratio"),
                age_band: age_band, gender: nil, imported_at: Time.current)
              count += 1
            end
          end
        end
      end
      Result.new(status: :ok, message: "트렌드 수집 완료", count: count)
    end
  end
end
