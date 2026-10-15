require "test_helper"
require "vips"

class SheetPipeline::ImageQualityGateTest < ActiveSupport::TestCase
  class FakeMessages
    attr_reader :calls

    def initialize(verdict: "통과", score: 91)
      @verdict = verdict
      @score = score
      @calls = 0
    end

    def create(**_options)
      @calls += 1
      checks = %w[full_garment single_item occlusion shape color].to_h { |name| [ name, "ok" ] }
      data = { score: @score, verdict: @verdict, reason: "내용 양호", checks: checks }
      Struct.new(:stop_reason, :content).new(nil, [ Struct.new(:type, :text).new("text", data.to_json) ])
    end
  end

  class FakeClient
    attr_reader :beta, :messages

    def initialize(messages)
      @messages = messages
      @beta = Struct.new(:messages).new(messages)
    end
  end

  setup do
    ImageQualityCheck.delete_all
  end

  test "큰 노이즈 이미지는 수치 통과하고 비전 점수를 저장한다" do
    messages = FakeMessages.new
    result = gate(noise_image(800), messages).call(row("P-800"))

    assert_equal "통과", result["이미지판정"]
    assert_equal 91, result["판정점수"]
    assert_match(/800px · Q- · 선명 \d+ · 뭉개짐/, result["수치"])
    assert_equal "수치·내용 기준 충족", result["판정사유"]
    assert_nil result[:halt]
    assert_equal 1, messages.calls
  end

  test "Q90 JPEG는 파일 오류 없이 품질 수치를 기록한다" do
    result = gate(jpeg_noise_image(90), FakeMessages.new).call(row("P-JPEG-90"))

    assert_equal "통과", result["이미지판정"]
    assert_match(/1000px · Q9\d · 선명/, result["수치"])
    assert_no_match(/파일 열리지 않음/, result["판정사유"])
  end

  test "Q60 JPEG는 품질 기준으로 반려한다" do
    result = gate(jpeg_noise_image(60), FakeMessages.new).call(row("P-JPEG-60"))

    assert_equal "반려", result["이미지판정"]
    assert_match(/JPEG 품질 Q60/, result["판정사유"])
    assert_match(/1000px · Q60/, result["수치"])
  end

  test "400px 이미지는 반려하고 비전을 호출하지 않는다" do
    messages = FakeMessages.new
    result = gate(noise_image(400), messages).call(row("P-400"))

    assert_equal "반려", result["이미지판정"]
    assert_equal true, result[:halt]
    assert_match(/짧은 변 400px/, result["판정사유"])
    assert_equal 0, messages.calls
  end

  test "600px 이미지는 보완이며 MD 진행이면 멈추지 않는다" do
    input = row("P-600", "진행").merge("상태" => "MD확인 대기")
    result = gate(noise_image(600), FakeMessages.new).call(input)

    assert_equal "보완", result["이미지판정"]
    assert_equal "대기", result["상태"]
    assert_nil result[:halt]
  end

  test "비전 설정이 없으면 통과 수치를 보완으로 낮추고 점수를 비운다" do
    previous = ENV.delete("ANTHROPIC_API_KEY")
    result = SheetPipeline::ImageQualityGate.new(fetcher: ->(_url) { noise_image(800) }).call(row("P-NOKEY"))

    assert_equal "보완", result["이미지판정"]
    assert_equal "", result["판정점수"]
    assert_match(/2차 내용 판정 미실행: ANTHROPIC_API_KEY 미설정/, result["판정사유"])
    assert_equal true, result[:halt]
  ensure
    ENV["ANTHROPIC_API_KEY"] = previous
  end

  test "3000x4000 Q90 JPEG의 수치가 통과하고 비전 키가 없으면 미실행 사유만 남긴다" do
    previous = ENV.delete("ANTHROPIC_API_KEY")
    bytes = jpeg_noise_image(90, width: 3000, height: 4000)
    result = SheetPipeline::ImageQualityGate.new(fetcher: ->(_url) { bytes }).call(row("P-LARGE-NOKEY"))

    assert_equal "보완", result["이미지판정"]
    assert_equal "2차 내용 판정 미실행: ANTHROPIC_API_KEY 미설정", result["판정사유"]
  ensure
    ENV["ANTHROPIC_API_KEY"] = previous
  end

  test "같은 상품과 파일 해시는 저장된 판정을 쓰고 비전을 다시 호출하지 않는다" do
    bytes = noise_image(800)
    first = FakeMessages.new
    gate(bytes, first).call(row("P-CACHE"))
    second = FakeMessages.new
    result = gate(bytes, second).call(row("P-CACHE"))

    assert_equal "통과", result["이미지판정"]
    assert_equal 0, second.calls
    assert_equal 1, ImageQualityCheck.where(product_code: "P-CACHE").count
  end

  test "다운로드 실패는 반려로 기록한다" do
    fetcher = ->(_url) { raise "접근 거부" }
    result = SheetPipeline::ImageQualityGate.new(fetcher: fetcher).call(row("P-FAIL"))

    assert_equal "반려", result["이미지판정"]
    assert_equal "파일 열리지 않음: 접근 거부", result["판정사유"]
    assert_equal true, result[:halt]
    assert_equal "반려", ImageQualityCheck.last.verdict
  end

  test "같은 다운로드 실패를 다시 확인하면 최근 판정 행을 재사용한다" do
    fetcher = ->(_url) { raise "접근 거부" }
    gate = SheetPipeline::ImageQualityGate.new(fetcher: fetcher)
    input = row("P-FAIL-CACHE")
    first = gate.call(input)
    check = ImageQualityCheck.find_by!(product_code: "P-FAIL-CACHE")
    second = gate.call(input)

    assert_equal first, second
    assert_equal 1, ImageQualityCheck.where(product_code: "P-FAIL-CACHE").count
    assert_equal check.id, ImageQualityCheck.find_by!(product_code: "P-FAIL-CACHE").id
    assert_nil check.image_sha256
  end

  private

  def gate(bytes, messages)
    SheetPipeline::ImageQualityGate.new(fetcher: ->(_url) { bytes }, client: FakeClient.new(messages))
  end

  def row(code, md = "")
    { "상품코드" => code, "이미지" => "https://example.test/image.png\nhttps://example.test/extra.png", "MD확인" => md }
  end

  def noise_image(size)
    random = Random.new(size)
    pixels = random.bytes(size * size)
    Vips::Image.new_from_memory(pixels, size, size, 1, :uchar).write_to_buffer(".png")
  end

  def jpeg_noise_image(quality, width: 1000, height: 1200)
    pixels = Random.new(quality).bytes(width * height)
    Vips::Image.new_from_memory(pixels, width, height, 1, :uchar).write_to_buffer(".jpg", Q: quality)
  end
end
