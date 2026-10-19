require "test_helper"
require "minitest/mock"

class Cutouts::RembgAdapterTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:success, :code, :body) do
    def is_a?(klass)
      klass == Net::HTTPSuccess ? success : super
    end
  end

  def setup
    @product = products(:one)
    @product.image.attach(io: file_fixture("product.png").open, filename: "product.png", content_type: "image/png")
    @record = ProductImageProcessing.create!(product: @product, kind: "cutout")
  end

  test "rembg 응답 PNG 를 cutout_image 로 첨부하고 비용 0을 돌려준다" do
    png = file_fixture("product.png").binread
    sent = nil
    fake_start = lambda do |host, port, **_opts, &block|
      http = Object.new
      http.define_singleton_method(:request) { |req| sent = [ host, port, req ]; FakeResponse.new(true, "200", png) }
      block.call(http)
    end

    result = Net::HTTP.stub(:start, fake_start) { Cutouts::RembgAdapter.new(@record).call }

    assert_equal({ cost_cents: 0 }, result)
    assert @product.reload.cutout_image.attached?
    assert_equal "image/png", @product.cutout_image.content_type
    assert_equal [ "127.0.0.1", 7000 ], sent.first(2)
    assert_equal "/api/remove", sent.last.path
  end

  test "rembg 오류 응답이면 예외를 내고 cutout_image 는 비워 둔다" do
    fake_start = lambda do |*_args, **_opts, &block|
      http = Object.new
      http.define_singleton_method(:request) { |_| FakeResponse.new(false, "500", "boom") }
      block.call(http)
    end

    error = assert_raises(RuntimeError) do
      Net::HTTP.stub(:start, fake_start) { Cutouts::RembgAdapter.new(@record).call }
    end

    assert_includes error.message, "HTTP 500"
    assert_not @product.reload.cutout_image.attached?
  end

  test "PNG 가 아닌 응답은 거부한다" do
    fake_start = lambda do |*_args, **_opts, &block|
      http = Object.new
      http.define_singleton_method(:request) { |_| FakeResponse.new(true, "200", "<html>") }
      block.call(http)
    end

    assert_raises(RuntimeError) do
      Net::HTTP.stub(:start, fake_start) { Cutouts::RembgAdapter.new(@record).call }
    end
    assert_not @product.reload.cutout_image.attached?
  end

  test "서버에 연결할 수 없으면 알기 쉬운 사유로 실패한다" do
    error = assert_raises(RuntimeError) do
      Net::HTTP.stub(:start, ->(*_args, **_opts) { raise Errno::ECONNREFUSED }) { Cutouts::RembgAdapter.new(@record).call }
    end

    assert_includes error.message, "rembg 서버에 연결할 수 없습니다"
  end

  test "자체 호스팅이라 과금 상한 집계에서 빠진다" do
    assert_not Cutouts::RembgAdapter.metered?
    @record.update!(status: "succeeded", provider: Cutouts::RembgAdapter.provider_name)

    assert_equal 0, ProductImageProcessing.external_calls.count
  end
end
