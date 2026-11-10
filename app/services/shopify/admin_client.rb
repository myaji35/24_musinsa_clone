require "net/http"

module Shopify
  class AdminClient < ApplicationService
    API_VERSION = "2026-10"

    class HttpAdapter
      def call(uri, headers:, body:)
        request = Net::HTTP::Post.new(uri, headers)
        request.body = body
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) { |http| http.request(request) }
      end
    end

    def initialize(http: HttpAdapter.new)
      @http = http
    end

    def sync(sku:, quantity:, price:)
      return failure("연결 안 됨") if ENV["SHOPIFY_ADMIN_TOKEN"].blank? || ENV["SHOPIFY_SHOP_DOMAIN"].blank?

      found = graphql(<<~GRAPHQL, query: "sku:#{sku}")
        query($query: String!) {
          productVariants(first: 10, query: $query) {
            nodes { id sku product { id } inventoryItem { id inventoryLevels(first: 2) { nodes { location { id } quantities(names: ["available"]) { name quantity } } } } }
          }
        }
      GRAPHQL
      variants = found.fetch("productVariants").fetch("nodes").select { |node| node["sku"] == sku }
      return failure("SKU가 없거나 중복됩니다") unless variants.one?
      variant = variants.first
      levels = variant.dig("inventoryItem", "inventoryLevels", "nodes")
      return failure("재고 위치를 하나로 지정해야 합니다") unless levels.one?

      level = levels.first
      graphql(<<~GRAPHQL, input: { name: "available", reason: "correction", quantities: [ { inventoryItemId: variant.dig("inventoryItem", "id"), locationId: level.dig("location", "id"), quantity: quantity, compareQuantity: level.fetch("quantities").find { |item| item["name"] == "available" }.fetch("quantity") } ] })
        mutation($input: InventorySetQuantitiesInput!) {
          inventorySetQuantities(input: $input) { userErrors { message } }
        }
      GRAPHQL
      graphql(<<~GRAPHQL, productId: variant.dig("product", "id"), variants: [ { id: variant["id"], price: price.to_s } ])
        mutation($productId: ID!, $variants: [ProductVariantsBulkInput!]!) {
          productVariantsBulkUpdate(productId: $productId, variants: $variants) { userErrors { message } }
        }
      GRAPHQL
      success
    rescue StandardError => e
      failure("쇼피파이 동기화 실패: #{e.class}")
    end

    private

    def graphql(query, variables)
      domain = ENV.fetch("SHOPIFY_SHOP_DOMAIN")
      raise ArgumentError, "스토어 도메인을 확인하세요" unless domain.match?(/\A[a-z0-9][a-z0-9-]*\.myshopify\.com\z/)

      response = @http.call(URI("https://#{domain}/admin/api/#{API_VERSION}/graphql.json"),
        headers: { "Content-Type" => "application/json", "X-Shopify-Access-Token" => ENV.fetch("SHOPIFY_ADMIN_TOKEN") },
        body: JSON.generate(query: query, variables: variables))
      raise IOError, "HTTP 오류" unless response.code.to_i == 200
      payload = JSON.parse(response.body)
      raise IOError, "GraphQL 오류" if payload["errors"].present?
      data = payload.fetch("data")
      raise IOError, "변경 거절" if data.values.any? { |value| value.is_a?(Hash) && value["userErrors"].present? }

      data
    end
  end
end
