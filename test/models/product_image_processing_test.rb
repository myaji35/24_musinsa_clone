require "test_helper"

class ProductImageProcessingTest < ActiveSupport::TestCase
  def setup
    @original_limit = ENV["IMAGE_PROCESSING_MONTHLY_LIMIT"]
  end

  def teardown
    ENV["IMAGE_PROCESSING_MONTHLY_LIMIT"] = @original_limit
  end

  test "kind와 status를 검증한다" do
    record = ProductImageProcessing.new(product: products(:one), kind: "cutout")
    assert record.valid?

    record.kind = "unknown"
    assert_not record.valid?
    assert_includes record.errors[:kind], "is not included in the list"

    record.kind = "try_on"
    record.status = "unknown"
    assert_not record.valid?
    assert_includes record.errors[:status], "is not included in the list"
  end

  test "월 상한 환경 변수가 없거나 잘못되면 0이다" do
    ENV.delete("IMAGE_PROCESSING_MONTHLY_LIMIT")
    assert_equal 0, ProductImageProcessing.monthly_limit

    ENV["IMAGE_PROCESSING_MONTHLY_LIMIT"] = "invalid"
    assert_equal 0, ProductImageProcessing.monthly_limit

    ENV["IMAGE_PROCESSING_MONTHLY_LIMIT"] = "-1"
    assert_equal 0, ProductImageProcessing.monthly_limit

    ENV["IMAGE_PROCESSING_MONTHLY_LIMIT"] = "3"
    assert_equal 3, ProductImageProcessing.monthly_limit
  end

  test "이번 달 실제 외부 호출만 상한에 포함한다" do
    ENV["IMAGE_PROCESSING_MONTHLY_LIMIT"] = "2"
    assert_not ProductImageProcessing.limit_reached?

    ProductImageProcessing.create!(product: products(:one), kind: "cutout", status: "failed")
    ProductImageProcessing.create!(product: products(:one), kind: "cutout", status: "skipped", provider: "api")
    assert_not ProductImageProcessing.limit_reached?

    ProductImageProcessing.create!(product: products(:one), kind: "cutout", status: "processing", provider: "api")
    assert_not ProductImageProcessing.limit_reached?

    old_record = ProductImageProcessing.create!(product: products(:one), kind: "cutout", status: "succeeded", provider: "api")
    old_record.update_columns(created_at: 1.month.ago)
    assert_not ProductImageProcessing.limit_reached?

    ProductImageProcessing.create!(product: products(:one), kind: "try_on", status: "failed", provider: "api")
    assert ProductImageProcessing.limit_reached?
  end
end
