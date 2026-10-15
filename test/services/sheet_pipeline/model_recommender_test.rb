require "test_helper"
require "vips"

class SheetPipeline::ModelRecommenderTest < ActiveSupport::TestCase
  Block = Struct.new(:type, :text)
  Response = Struct.new(:stop_reason, :stop_details, :content)

  class FakeMessages
    attr_reader :calls, :options

    def initialize
      @calls = 0
    end

    def create(**options)
      @calls += 1
      @options = options
      ranked = %w[one two three].map { |handle| { handle: handle, reason: "#{handle} 소구점에 어울립니다." } }
      Response.new(:end_turn, nil, [ Block.new("text", { ranked_characters: ranked }.to_json) ])
    end
  end

  def setup
    @old_key = ENV["ANTHROPIC_API_KEY"]
    ENV["ANTHROPIC_API_KEY"] = "test-key"
    %w[one two three].each { |handle| Character.create!(name: handle.capitalize, handle: handle, status: "active") }
    @messages = FakeMessages.new
    @client = Struct.new(:beta).new(Struct.new(:messages).new(@messages))
    @fetches = []
    @fetcher = ->(url) do
      @fetches << url
      Vips::Image.black(1200, 800).write_to_buffer(".png")
    end
  end

  def teardown
    ENV["ANTHROPIC_API_KEY"] = @old_key
  end

  test "이미지와 소구포인트를 보내 세 줄 추천을 기록한다" do
    result = recommender.call(row)

    assert_equal "추천완료", result["상태"]
    assert_equal 3, result["추천 모델"].lines.count
    assert_equal "1. One — one 소구점에 어울립니다.", result["추천 모델"].lines.first.strip
    assert_equal [ "https://example.test/first.png" ], @fetches
    content = @messages.options[:messages][0][:content]
    request = JSON.parse(content[0][:text])
    assert_equal({ "code" => "P-1", "name" => "셔츠", "price_color" => "흰색" }, request["product"])
    assert_equal [ "시원함", "구김 적음" ], request["appeal_points"]
    image = Vips::Image.new_from_buffer(Base64.strict_decode64(content[1][:source][:data]), "")
    assert_equal [ 1024, 683 ], [ image.width, image.height ]
  end

  test "이미 추천된 행은 다운로드와 클라이언트 호출을 생략한다" do
    assert_nil recommender.call(row.merge("추천 모델" => "기존 추천"))
    assert_empty @fetches
    assert_equal 0, @messages.calls
  end

  test "키가 없으면 예외를 올린다" do
    ENV.delete("ANTHROPIC_API_KEY")
    error = assert_raises(ProductAnalyses::Analyzer::Error) { recommender.call(row) }
    assert_match(/ANTHROPIC_API_KEY 미설정/, error.message)
    assert_equal 0, @messages.calls
  end

  private

  def recommender
    SheetPipeline::ModelRecommender.new(fetcher: @fetcher, client: @client)
  end

  def row
    { "상품코드" => "P-1", "상품명" => "셔츠", "가격·색상" => "흰색",
      "이미지" => "https://example.test/first.png\nhttps://example.test/second.png",
      "소구포인트1" => " 시원함 ", "소구포인트2" => "", "소구포인트3" => "구김 적음" }
  end
end
