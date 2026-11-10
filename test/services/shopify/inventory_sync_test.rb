require "test_helper"

class ShopifyInventorySyncTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  class FakeHttp
    attr_reader :requests

    def initialize(error: false)
      @requests = []
      @error = error
    end

    def call(_uri, headers:, body:)
      request = JSON.parse(body)
      @requests << request
      data = if request["query"].include?("query($query")
        { productVariants: { nodes: [ { id: "variant", sku: "JIEUM-L01", product: { id: "product" }, inventoryItem: { id: "inventory", inventoryLevels: { nodes: [ { location: { id: "location" }, quantities: [ { name: "available", quantity: 0 } ] } ] } } } ] } }
      else
        { mutation: { userErrors: @error ? [ { message: "거절" } ] : [] } }
      end
      Struct.new(:code, :body).new("200", JSON.generate(data: data))
    end
  end

  setup do
    @saved = ENV.to_h.slice("SHOPIFY_ADMIN_TOKEN", "SHOPIFY_SHOP_DOMAIN", "SHOPIFY_SALES_ENABLED", "SHOPIFY_SYNC_ENABLED", "SHOPIFY_KRW_PER_USD")
    ENV["SHOPIFY_ADMIN_TOKEN"] = "테스트"
    ENV["SHOPIFY_SHOP_DOMAIN"] = "test.myshopify.com"
    ENV.delete("SHOPIFY_SALES_ENABLED")
    ENV.delete("SHOPIFY_SYNC_ENABLED")
    @product = products(:one)
    @product.update!(name: "숄칼라 벨티드 울 랩코트", price: 189000)
    @variant = variants(:one)
    @variant.update!(product: @product, color: "카멜", stock: 4)
    @product.variants.where.not(id: @variant.id).update_all(color: "다른 색상")
    @product.variants.create!(color: "카멜", size: "추가", stock: 7)
    @http = FakeHttp.new
    @client = Shopify::AdminClient.new(http: @http)
  end

  teardown do
    %w[SHOPIFY_ADMIN_TOKEN SHOPIFY_SHOP_DOMAIN SHOPIFY_SALES_ENABLED SHOPIFY_SYNC_ENABLED SHOPIFY_KRW_PER_USD].each { |key| ENV[key] = @saved[key] }
  end

  test "매핑 33개는 고유하며 모든 상품 가격이 표와 일치한다" do
    prices = [ 189, 199, 239, 189, 169, 169, 209, 219, 179, 189, 109, 199, 179, 189, 199, 159, 229, 119, 109, 179, 249, 199, 179, 219, 219, 169, 179, 229, 199, 249, 239, 249, 239 ]
    rows = Shopify::Listings.all
    assert_equal 33, rows.size
    assert_equal 33, rows.pluck("sku").uniq.size
    assert_equal (1..33).map { |number| "JIEUM-L%02d" % number }, rows.pluck("sku")
    assert_equal 33, rows.map { |row| [ row["product_name"], row["color"] ] }.uniq.size
    rows.zip(prices).each do |row, price|
      product = Product.find_by(name: row["product_name"]) || @product.dup
      product.update!(name: row["product_name"], price: price * 1000)
      assert_equal row["price_usd"], Shopify::Pricing.overseas_usd(Shopify::Listings.product(row).price, rate: 1450), row["look"]
    end
    assert_equal 269, Shopify::Pricing.overseas_usd(191400, rate: 1450)
    assert_raises(ArgumentError) { Shopify::Pricing.overseas_usd(100, rate: 0) }
    ENV["SHOPIFY_KRW_PER_USD"] = "1000"
    assert_equal 379, Shopify::Pricing.overseas_usd(189000)
  end

  test "판매 스위치 기본값은 재고 0 전송" do
    result = Shopify::InventorySync.call(variant_id: @variant.id, client: @client)
    assert result.success?
    assert result.data.first[:sent]
    assert_equal 0, @http.requests[1].dig("variables", "input", "quantities", 0, "quantity")
    assert_equal "259", @http.requests[2].dig("variables", "variants", 0, "price")
  end

  test "판매 스위치가 켜지면 색상 재고 합계 전송" do
    ENV["SHOPIFY_SALES_ENABLED"] = "1"
    Shopify::InventorySync.call(variant_id: @variant.id, client: @client)
    assert_equal 11, @http.requests[1].dig("variables", "input", "quantities", 0, "quantity")
  end

  test "토큰이 없으면 HTTP 호출 없음" do
    ENV.delete("SHOPIFY_ADMIN_TOKEN")
    result = Shopify::InventorySync.call(variant_id: @variant.id, client: @client)
    assert_empty @http.requests
    assert_equal "연결 안 됨", result.data.first[:skipped_reason]
  end

  test "변경 오류는 성공으로 기록하지 않는다" do
    result = Shopify::InventorySync.call(variant_id: @variant.id, client: Shopify::AdminClient.new(http: FakeHttp.new(error: true)))
    assert_not result.data.first[:sent]
  end

  test "동기화 스위치가 꺼지면 작업을 넣지 않는다" do
    assert_no_enqueued_jobs(only: ShopifyInventorySyncJob) { @variant.stock_logs.create!(log_type: "in", quantity: 1) }
  end

  test "동기화 스위치가 켜지면 매핑된 재고만 작업을 넣는다" do
    ENV["SHOPIFY_SYNC_ENABLED"] = "1"
    assert_enqueued_with(job: ShopifyInventorySyncJob, args: [ @variant.id ]) { @variant.stock_logs.create!(log_type: "in", quantity: 1) }
    @variant.update!(color: "미매핑")
    assert_no_enqueued_jobs(only: ShopifyInventorySyncJob) { @variant.stock_logs.create!(log_type: "in", quantity: 1) }
  end
end
