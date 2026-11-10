module Shopify
  class InventorySync < ApplicationService
    def initialize(variant_id: nil, client: AdminClient.new)
      @variant_id = variant_id
      @client = client
    end

    def call
      rows = @variant_id ? Listings.for_variant(Variant.find(@variant_id)) : Listings.all
      results = rows.map do |row|
        result = { look: row["look"], sku: row["sku"] }
        product = Listings.product(row) if row["product_name"].present?
        variants = product&.variants&.where(color: row["color"])
        if !variants&.exists?
          result.merge(skipped_reason: row["unmatched_reason"] || "몰 상품·색상이 없거나 상품명이 중복됩니다")
        else
          quantity = ENV["SHOPIFY_SALES_ENABLED"] == "1" ? variants.sum(:stock) : 0
          price = Pricing.overseas_usd(product.price)
          response = @client.sync(sku: row["sku"], quantity: quantity, price: price)
          result.merge(quantity: quantity, price_usd: price, sent: response.success?, skipped_reason: response.error)
        end
      end
      success(results)
    end
  end
end
