require "test_helper"

class Webhooks::ShopifyControllerTest < ActionDispatch::IntegrationTest
  setup do
    @secret = ENV["SHOPIFY_WEBHOOK_SECRET"]
    @sync = ENV["SHOPIFY_SYNC_ENABLED"]
    ENV["SHOPIFY_WEBHOOK_SECRET"] = "테스트 서명키"
    ENV.delete("SHOPIFY_SYNC_ENABLED")
    @product = products(:one)
    @product.update!(name: "숄칼라 벨티드 울 랩코트")
    @variant = variants(:one)
    @variant.update!(color: "카멜", stock: 8)
    @other = @product.variants.create!(color: "카멜", size: "추가", stock: 2)
  end

  teardown do
    ENV["SHOPIFY_WEBHOOK_SECRET"] = @secret
    ENV["SHOPIFY_SYNC_ENABLED"] = @sync
  end

  def deliver(sku: "JIEUM-L01", quantity: 3, id: "주문웹훅", signature: nil)
    body = JSON.generate(id: 123, name: "#1001", line_items: [ { sku: sku, quantity: quantity } ])
    signature ||= Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", ENV.fetch("SHOPIFY_WEBHOOK_SECRET"), body))
    post "/webhooks/shopify/orders_create", params: body, headers: { "CONTENT_TYPE" => "application/json", "X-Shopify-Hmac-Sha256" => signature, "X-Shopify-Webhook-Id" => id }
  end

  test "잘못된 서명은 401이며 차감하지 않는다" do
    assert_no_difference([ "StockLog.count", "ShopifyWebhookReceipt.count" ]) { deliver(signature: "실패") }
    assert_response :unauthorized
    assert_equal 8, @variant.reload.stock
  end

  test "정상 주문은 재고 많은 사이즈부터 한 번만 차감한다" do
    assert_difference "StockLog.count", 2 do
      deliver(quantity: 9)
    end
    assert_response :ok
    assert_equal 0, @variant.reload.stock
    assert_equal 1, @other.reload.stock
    assert_equal "쇼피파이 주문 #1001", StockLog.last.note
    assert ShopifyWebhookReceipt.last.processed_at
    assert_no_difference "StockLog.count" do
      deliver(quantity: 9)
    end
    assert_response :ok
  end

  test "미매핑 SKU는 차감 없이 사유를 남기고 200" do
    assert_no_difference("StockLog.count") { deliver(sku: "UNKNOWN") }
    assert_response :ok
    assert_includes ShopifyWebhookReceipt.last.issues.first, "미매핑"
  end

  test "재고 부족은 부분 차감 없이 200" do
    assert_no_difference("StockLog.count") { deliver(quantity: 100) }
    assert_response :ok
    assert_equal 8, @variant.reload.stock
    assert_includes ShopifyWebhookReceipt.last.issues.first, "재고 부족"
  end
end
