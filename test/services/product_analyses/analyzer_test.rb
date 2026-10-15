require "test_helper"

class ProductAnalysesAnalyzerTest < ActiveSupport::TestCase
  Response = Struct.new(:stop_reason, :stop_details, :content, :model, :usage, keyword_init: true)
  StopDetails = Struct.new(:category, keyword_init: true)
  Block = Struct.new(:type, :text, keyword_init: true)
  Usage = Struct.new(:input_tokens, :output_tokens, keyword_init: true)

  class FakeMessages
    attr_reader :options

    def initialize(response)
      @response = response
    end

    def create(**options)
      @options = options
      raise @response if @response.is_a?(Exception)

      @response
    end
  end

  def setup
    @old_key = ENV["ANTHROPIC_API_KEY"]
    ENV["ANTHROPIC_API_KEY"] = "test-key"
    @first = Character.create!(name: "첫째", handle: "first", status: "active")
    @second = Character.create!(name: "둘째", handle: "second", status: "planned")
    @third = Character.create!(name: "셋째", handle: "third", status: "active")
    @analysis = products(:one).product_analyses.create!
  end

  def teardown
    ENV["ANTHROPIC_API_KEY"] = @old_key
  end

  test "성공 응답을 저장하고 요청 옵션과 이미지 블록을 확인한다" do
    products(:one).image.attach(io: File.open(file_fixture("product.png")), filename: "product.png", content_type: "image/png")
    result, messages = analyze(response(payload), appeal_points: [ "가벼운 착용감" ])
    assert result.success?
    assert_equal "done", @analysis.reload.status
    assert_equal @first, @analysis.character
    assert_equal @second, @analysis.alt_character
    assert_equal [ "first", "second", "third" ], JSON.parse(@analysis.ranking_json).map { |entry| entry["handle"] }
    assert_equal [ 1, 2, 3 ], JSON.parse(@analysis.ranking_json).map { |entry| entry["rank"] }
    assert_equal "peer_fit", @analysis.concept_angle
    assert_equal 2, @analysis.target_units
    assert_equal 39_800, @analysis.target_revenue
    assert_equal 0.00044, @analysis.cost_usd.to_f
    assert_equal :"claude-opus-5-5", messages.options[:model]
    assert_equal [ "server-side-fallback-2026-07-01" ], messages.options[:betas]
    assert_equal "default", messages.options[:fallbacks]
    assert_equal "json_schema", messages.options.dig(:output_config, :format, :type)
    schema = messages.options.dig(:output_config, :format, :schema).to_json
    assert_not_includes schema, '"minimum"'
    assert_not_includes schema, '"maximum"'
    assert_not messages.options.key?(:thinking)
    assert_not messages.options.key?(:temperature)
    assert_equal "image", messages.options[:messages][0][:content][1][:type]
    request = JSON.parse(messages.options[:messages][0][:content][0][:text])
    assert_equal [ "가벼운 착용감" ], request["appeal_points"]
  end

  test "거절은 실패 이력으로 남는다" do
    result, = analyze(response(payload, stop_reason: :refusal, stop_details: StopDetails.new(category: :cyber)))
    assert result.failure?
    assert_includes @analysis.reload.error_message, "cyber"
  end

  test "로스터 밖 캐릭터는 실패한다" do
    result, = analyze(response(payload.merge("ranked_characters" => ranking("first", "second", "missing"))))
    assert result.failure?
    assert_match(/추천 3명 검증 실패: 로스터 밖 handle/, @analysis.reload.error_message)
  end

  test "중복과 두 명 추천은 실패한다" do
    [ ranking("first", "first", "third"), ranking("first", "second") ].each do |entries|
      result, = analyze(response(payload.merge("ranked_characters" => entries)))
      assert result.failure?
      assert_match(/추천 3명 검증 실패:/, @analysis.reload.error_message)
    end
  end

  test "초이는 로스터에서 제외되고 응답에 있어도 실패한다" do
    Character.create!(name: "초이", handle: "ChOi", status: "active")
    result, messages = analyze(response(payload))
    assert result.success?
    request = JSON.parse(messages.options[:messages][0][:content][0][:text])
    assert_not_includes request["characters"].map { |entry| entry["handle"] }, "ChOi"

    result, = analyze(response(payload.merge("ranked_characters" => ranking("first", "second", "ChOi"))))
    assert result.failure?
    assert_match(/추천 3명 검증 실패:/, @analysis.reload.error_message)
  end

  test "시트 추천은 같은 순위를 반환하고 분석 행을 저장하지 않는다" do
    messages = FakeMessages.new(response(payload))
    client = Struct.new(:beta).new(Struct.new(:messages).new(messages))
    before_count = ProductAnalysis.count

    ranking = ProductAnalyses::Analyzer.rank_for_sheet(details: { code: "P-1" }, image_jpeg: "jpeg",
      appeal_points: [ "가벼움" ], client: client)

    assert_equal [ "first", "second", "third" ], ranking.map { |entry| entry[:handle] }
    assert_equal before_count, ProductAnalysis.count
    assert_equal [ "가벼움" ], JSON.parse(messages.options[:messages][0][:content][0][:text])["appeal_points"]
  end

  test "범위 밖 확신도는 실패한다" do
    [ -0.1, 1.1 ].each do |confidence|
      result, = analyze(response(payload.merge("confidence" => confidence)))
      assert result.failure?
      assert_equal "failed", @analysis.reload.status
      assert_equal "확신도 범위 오류(0~1 밖)", @analysis.error_message
    end
  end

  test "JSON 파싱 실패를 기록한다" do
    result, = analyze(response("invalid"))
    assert result.failure?
    assert_equal "failed", @analysis.reload.status
  end

  test "키가 없으면 호출하지 않고 실패한다" do
    ENV.delete("ANTHROPIC_API_KEY")
    result, messages = analyze(response(payload))
    assert result.failure?
    assert_equal "ANTHROPIC_API_KEY 미설정 — 분석 불가", @analysis.reload.error_message
    assert_nil messages.options
  end

  test "연결 오류를 기록한다" do
    error = Anthropic::Errors::APIConnectionError.new(url: URI("https://example.com"))
    result, = analyze(error)
    assert result.failure?
    assert_match "APIConnectionError", @analysis.reload.error_message
  end

  private

  def analyze(res, appeal_points: [])
    messages = FakeMessages.new(res)
    client = Struct.new(:beta).new(Struct.new(:messages).new(messages))
    [ ProductAnalyses::Analyzer.new(@analysis, client: client, appeal_points: appeal_points).call, messages ]
  end

  def response(data, stop_reason: :end_turn, stop_details: nil)
    Response.new(stop_reason: stop_reason, stop_details: stop_details, content: [ Block.new(type: "text", text: data.is_a?(Hash) ? data.to_json : data) ],
      model: "claude-opus-5-5", usage: Usage.new(input_tokens: 100, output_tokens: 2))
  end

  def payload
    { "style_axis" => "캐주얼·데일리", "target_age_band" => 20, "season" => "사계절",
      "ranked_characters" => ranking("first", "second", "third"),
      "concept_angle" => "peer_fit", "concept_title" => "일상 핏", "hook_line" => "오늘의 핏",
      "attributes" => { "colors" => [ "흰색" ], "silhouette" => nil, "tpo" => [ "일상" ], "material_guess" => nil },
      "reasoning" => "잘 어울립니다.", "confidence" => 0.8 }
  end

  def ranking(*handles)
    handles.map { |handle| { "handle" => handle, "reason" => "잘 어울립니다." } }
  end
end
