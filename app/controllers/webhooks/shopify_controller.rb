require "openssl"
require "base64"

module Webhooks
  class ShopifyController < ApplicationController
    skip_before_action :require_admin
    skip_forgery_protection

    def orders_create
      body = request.raw_post
      secret = ENV["SHOPIFY_WEBHOOK_SECRET"]
      signature = request.headers["X-Shopify-Hmac-Sha256"].to_s
      expected = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", secret, body)) if secret.present?
      return head :unauthorized unless expected && ActiveSupport::SecurityUtils.secure_compare(expected, signature)

      payload = JSON.parse(body)
      webhook_id = request.headers["X-Shopify-Webhook-Id"]
      return head :bad_request if webhook_id.blank?

      ShopifyWebhookReceipt.transaction do
        unless ShopifyWebhookReceipt.exists?(webhook_id: webhook_id)
          receipt = ShopifyWebhookReceipt.create!(webhook_id: webhook_id, topic: "orders/create", shopify_order_id: payload["id"].to_s)
          issues = Array(payload["line_items"]).filter_map { |item| deduct(item, payload["name"]) }
          receipt.update!(processed_at: Time.current, issues: issues)
        end
      end
      head :ok
    rescue ActiveRecord::RecordNotUnique
      head :ok
    rescue JSON::ParserError
      head :bad_request
    end

    private

    def deduct(item, name)
      row = Shopify::Listings.all.find { |listing| listing["sku"] == item["sku"] }
      product = Shopify::Listings.product(row) if row && row["product_name"].present?
      quantity = item["quantity"]
      issue = "미매핑 SKU: #{item['sku']}" unless product
      issue ||= "수량 오류: #{item['sku']}" unless quantity.is_a?(Integer) && quantity.positive?
      return record_issue(issue) if issue

      begin
        Variant.transaction(requires_new: true) do
          variants = product.variants.where(color: row["color"]).order(stock: :desc, id: :asc).lock.to_a
          raise InsufficientStock if variants.sum(&:stock) < quantity
          remaining = quantity
          variants.each do |variant|
            take = [ variant.stock, remaining ].min
            next if take.zero?

            changed = Variant.where(id: variant.id).where("stock >= ?", take).update_all([ "stock = stock - ?", take ])
            raise InsufficientStock unless changed == 1

            StockLog.create!(variant: variant, log_type: "out", quantity: take, note: "쇼피파이 주문 ##{name.to_s.delete_prefix('#')}", skip_variant_stock_update: true)
            remaining -= take
            break if remaining.zero?
          end
        end
        nil
      rescue InsufficientStock
        record_issue("재고 부족: #{item['sku']}")
      end
    end

    def record_issue(message)
      Rails.logger.warn("쇼피파이 주문: #{message}")
      message
    end

    class InsufficientStock < StandardError; end
  end
end
