class ShopifyInventorySyncJob < ApplicationJob
  queue_as :default

  def perform(variant_id)
    return unless ENV["SHOPIFY_SYNC_ENABLED"] == "1"
    return unless Variant.exists?(variant_id)

    result = Shopify::InventorySync.call(variant_id: variant_id)
    Rails.logger.warn("쇼피파이 동기화 결과: #{result.data.inspect}") if result.data&.any? { |row| row[:skipped_reason] }
  end
end
