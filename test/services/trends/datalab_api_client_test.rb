require "test_helper"

class Trends::DatalabApiClientTest < ActiveSupport::TestCase
  class FakeHttp
    attr_reader :requests
    def initialize
      @requests = []
    end

    def start(*)
      yield self
    end

    def request(request)
      @requests << request
      Struct.new(:code, :body).new("200", { results: [ { title: "코트", data: [ { period: "2026-10-12", ratio: 45.5 } ] } ] }.to_json)
    end
  end

  test "키가 없으면 HTTP 없이 건너뛴다" do
    client = Trends::DatalabApiClient.new(env: {}, http: Object.new)
    assert_not client.configured?
    assert_equal :skipped, client.call.status
    assert_match "CSV 업로드", client.call.message
  end

  test "가짜 HTTP 응답을 저장하고 주간 카테고리와 연령대를 전달한다" do
    http = FakeHttp.new
    client = Trends::DatalabApiClient.new(env: { "NAVER_DATALAB_CLIENT_ID" => "fake", "NAVER_DATALAB_CLIENT_SECRET" => "fake" },
      http: http, categories: { "코트" => "test-code" })
    assert_equal :ok, client.call(age_band: 20).status
    snapshot = TrendSnapshot.sole
    assert_equal 45.5, snapshot.ratio
    assert_equal 20, snapshot.age_band
    assert_equal "datalab_api", snapshot.source
    body = JSON.parse(http.requests.first.body)
    assert_equal "week", body["timeUnit"]
    assert_equal [ "20" ], body["ages"]
    assert_equal [ { "name" => "코트", "param" => [ "test-code" ] } ], body["category"]
    assert_no_difference("TrendSnapshot.count") { client.call(age_band: 20) }
  end
end
