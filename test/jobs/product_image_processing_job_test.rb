require "test_helper"
require "minitest/mock"

class ProductImageProcessingJobTest < ActiveSupport::TestCase
  def setup
    @original_limit = ENV["IMAGE_PROCESSING_MONTHLY_LIMIT"]
    ENV["IMAGE_PROCESSING_MONTHLY_LIMIT"] = "10"
    @original_adapters = ProductImageProcessingJob::ADAPTERS.dup
    @record = ProductImageProcessing.create!(product: products(:one), kind: "cutout")
  end

  def teardown
    ENV["IMAGE_PROCESSING_MONTHLY_LIMIT"] = @original_limit
    ProductImageProcessingJob::ADAPTERS.replace(@original_adapters)
  end

  test "상한 0에서는 외부 호출 없이 건너뛴다" do
    ENV["IMAGE_PROCESSING_MONTHLY_LIMIT"] = "0"
    calls = 0
    ProductImageProcessingJob::ADAPTERS["cutout"] = Class.new do
      define_singleton_method(:provider_name) { "api" }
      define_method(:initialize) { |_| calls += 1 }
    end

    ProductImageProcessingJob.perform_now(@record.id)

    assert_equal 0, calls
    assert_equal "skipped", @record.reload.status
    assert_equal "월 호출 상한 초과(0건)", @record.error_message
    assert_nil @record.provider
    assert_not_nil @record.finished_at
  end

  test "누끼 기본 어댑터는 자체 호스팅 rembg 다" do
    assert_equal Cutouts::RembgAdapter, ProductImageProcessingJob::ADAPTERS["cutout"]
  end

  test "과금 없는 어댑터는 상한 0이어도 실행한다" do
    ENV["IMAGE_PROCESSING_MONTHLY_LIMIT"] = "0"
    ProductImageProcessingJob::ADAPTERS["cutout"] = Class.new do
      define_singleton_method(:provider_name) { "self-hosted:test" }
      define_singleton_method(:metered?) { false }
      define_method(:initialize) { |_| }
      define_method(:call) { { cost_cents: 0 } }
    end

    ProductImageProcessingJob.perform_now(@record.id)

    assert_equal "succeeded", @record.reload.status
    assert_equal "self-hosted:test", @record.provider
  end

  test "어댑터가 없으면 실패 사유를 저장한다" do
    record = ProductImageProcessing.create!(product: products(:one), kind: "try_on")

    ProductImageProcessingJob.perform_now(record.id)

    assert_equal "failed", record.reload.status
    assert_equal "어댑터 미구현: try_on", record.error_message
    @record = record
    assert_not_nil @record.finished_at
  end

  test "어댑터 예외는 기록하고 Sentry에 전달한다" do
    error = StandardError.new("실패")
    ProductImageProcessingJob::ADAPTERS["cutout"] = Class.new do
      define_singleton_method(:provider_name) { "api" }
      define_method(:initialize) { |_| }
      define_method(:call) { raise error }
    end
    captured = nil

    Sentry.stub(:capture_exception, ->(exception, extra:) { captured = [ exception, extra ] }) do
      ProductImageProcessingJob.perform_now(@record.id)
    end

    assert_equal "failed", @record.reload.status
    assert_equal "실패", @record.error_message
    assert_equal "api", @record.provider
    assert_not_nil @record.started_at
    assert_not_nil @record.finished_at
    assert_equal [ error, { product_image_processing_id: @record.id } ], captured
  end

  test "성공하면 비용과 완료 시간을 저장한다" do
    ProductImageProcessingJob::ADAPTERS["cutout"] = Class.new do
      define_singleton_method(:provider_name) { "api" }
      define_method(:initialize) { |_| }
      define_method(:call) { { cost_cents: 120 } }
    end

    ProductImageProcessingJob.perform_now(@record.id)

    assert_equal "succeeded", @record.reload.status
    assert_equal "api", @record.provider
    assert_equal 120, @record.cost_cents
    assert_not_nil @record.started_at
    assert_not_nil @record.finished_at
  end
end
