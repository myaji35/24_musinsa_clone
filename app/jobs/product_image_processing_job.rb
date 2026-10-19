class ProductImageProcessingJob < ApplicationJob
  ADAPTERS = { "cutout" => Cutouts::RembgAdapter }

  def perform(product_image_processing_id)
    record = ProductImageProcessing.find(product_image_processing_id)
    return if record.status == "succeeded"

    adapter = ADAPTERS[record.kind]
    unless adapter
      record.mark_failed!("어댑터 미구현: #{record.kind}")
      return
    end

    if metered?(adapter) && ProductImageProcessing.limit_reached?
      record.mark_skipped!("월 호출 상한 초과(#{ProductImageProcessing.monthly_limit}건)")
      return
    end

    record.update!(status: "processing", started_at: Time.current, provider: adapter.provider_name)
    result = adapter.new(record).call
    record.update!(status: "succeeded", cost_cents: result.fetch(:cost_cents), finished_at: Time.current)
  rescue StandardError => e
    record&.mark_failed!(e.message.first(500))
    Sentry.capture_exception(e, extra: { product_image_processing_id: product_image_processing_id })
    Rails.logger.error("ProductImageProcessingJob failed (#{product_image_processing_id}): #{e.class}: #{e.message}")
  end

  private

  # metered? 를 밝히지 않은 어댑터는 과금 공급사로 보고 상한을 적용한다.
  def metered?(adapter)
    !adapter.respond_to?(:metered?) || adapter.metered?
  end
end
