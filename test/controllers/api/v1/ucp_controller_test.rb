require "test_helper"

class Api::V1::UcpControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
  end

  test "API 키가 미설정이면 서비스 불가 오류를 반환한다" do
    with_ucp_api_key(nil) do
      get "/api/v1/ucp/products"

      assert_response :service_unavailable
      assert_equal "error", response.parsed_body["status"]
    end
  end

  test "API 키가 설정되어도 헤더가 없으면 인증을 거부한다" do
    with_ucp_api_key("test-key") do
      get "/api/v1/ucp/products"

      assert_response :unauthorized
    end
  end

  test "잘못된 API 키로 접근하면 인증을 거부한다" do
    with_ucp_api_key("test-key") do
      get "/api/v1/ucp/products", headers: { "X-API-Key" => "wrong-key" }

      assert_response :unauthorized
    end
  end

  test "올바른 API 키는 헤더와 파라미터 모두 접근을 허용한다" do
    with_ucp_api_key("test-key") do
      get "/api/v1/ucp/products", headers: { "X-API-Key" => "test-key" }

      assert_response :ok
      assert_equal "success", response.parsed_body["status"]

      get "/api/v1/ucp/products", params: { api_key: "test-key" }

      assert_response :ok
      assert_equal "success", response.parsed_body["status"]
    end
  end

  test "상품의 옵션 재고와 상세 사양 및 세탁방법을 반환한다" do
    product = Product.create!(
      name: "UCP 상세 상품", price: 10000, brand: "테스트", category: "상의", status: "published",
      spec: {
        "measurements" => { "M" => { "총장" => "65", "어깨너비" => "" }, "L" => { "총장" => "" } },
        "material" => { "겉감" => "면 100%", "안감" => "TODO: 확인" },
        "fit" => { "핏" => "레귤러", "계절" => %w[봄 가을] }
      },
      info_notice: { "세탁방법" => "찬물 손세탁" }
    )
    available = product.variants.create!(color: "black", size: "M", stock: 3)
    unavailable = product.variants.create!(color: "white", size: "L", stock: 0)
    unavailable.update_column(:stock, nil)

    with_ucp_api_key("test-key") do
      get "/api/v1/ucp/products", headers: { "X-API-Key" => "test-key" }

      assert_response :ok
      data = response.parsed_body["products"].find { |entry| entry["product_id"] == product.id }
      assert_equal 3, data["stock_total"]
      assert_equal true, data["in_stock"]
      assert_equal 2, data["variants"].size
      variants = data["variants"].index_by { |entry| entry["variant_id"] }
      assert_equal({ "variant_id" => available.id, "sku_code" => available.sku_code,
                     "color" => "black", "size" => "M", "stock" => 3, "in_stock" => true }, variants[available.id])
      assert_equal({ "variant_id" => unavailable.id, "sku_code" => unavailable.sku_code,
                     "color" => "white", "size" => "L", "stock" => 0, "in_stock" => false }, variants[unavailable.id])
      assert_equal({ "M" => { "총장" => "65" } }, data["measurements"])
      assert_equal({ "겉감" => "면 100%" }, data["materials"])
      assert_equal({ "핏" => "레귤러", "계절" => %w[봄 가을] }, data["fit"])
      assert_equal "찬물 손세탁", data["care_instructions"]
    end
  end

  test "세탁방법이 비었거나 TODO이면 nil을 반환한다" do
    product = Product.create!(name: "UCP 세탁 상품", price: 10000, brand: "테스트", category: "상의", status: "published")

    with_ucp_api_key("test-key") do
      [ nil, "", "TODO: 확인" ].each do |value|
        product.update!(info_notice: { "세탁방법" => value })
        Rails.cache.clear

        get "/api/v1/ucp/products", headers: { "X-API-Key" => "test-key" }

        assert_response :ok
        data = response.parsed_body["products"].find { |entry| entry["product_id"] == product.id }
        assert data.key?("care_instructions")
        assert_nil data["care_instructions"]
        assert_equal({}, data["measurements"])
        assert_equal({}, data["materials"])
        assert_equal({}, data["fit"])
      end
    end
  end

  private

  def with_ucp_api_key(key)
    original_key = ENV["UCP_API_KEY"]
    key.nil? ? ENV.delete("UCP_API_KEY") : ENV["UCP_API_KEY"] = key
    yield
  ensure
    original_key.nil? ? ENV.delete("UCP_API_KEY") : ENV["UCP_API_KEY"] = original_key
  end
end
