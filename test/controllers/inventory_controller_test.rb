require "test_helper"

class InventoryControllerTest < ActionDispatch::IntegrationTest
  def setup
    @product = Product.create!(
      name: "Test Product",
      price: 50000,
      brand: "Test Brand",
      category: "Top"
    )

    @variant = @product.variants.create!(
      barcode: "CTRL-TEST-001",
      color: "Black",
      size: "M",
      stock: 10,
      min_stock: 5
    )
  end

  # GET /inventory/scan
  test "should get scan" do
    get inventory_scan_url
    assert_response :success
  end

  test "should get scan with existing barcode" do
    variant = variants(:one)
    get inventory_scan_url, params: { barcode: variant.barcode }

    assert_response :success
    assert_includes response.body, variant.product.name
    assert_select "p", text: "컬러: #{variant.color} / 사이즈: #{variant.size}"
    assert_select "p", text: "현재 재고: #{variant.stock}개"
    assert_select "a[href=?]", inventory_stock_in_path(barcode: variant.barcode)
    assert_select "a[href=?]", inventory_stock_out_path(barcode: variant.barcode)
  end

  test "should get scan with nonexistent barcode" do
    get inventory_scan_url, params: { barcode: "NONEXISTENT" }

    assert_response :success
    assert_includes response.body, "등록되지 않은 바코드입니다"
  end

  # GET /inventory/stock_in
  test "should get stock_in" do
    get inventory_stock_in_url
    assert_response :success
  end

  # GET /inventory/stock_in with barcode parameter
  test "should get stock_in with variant" do
    get inventory_stock_in_url, params: { barcode: @variant.barcode }
    assert_response :success
  end

  # POST /inventory/stock_in - Success
  test "should create stock_in successfully" do
    assert_difference "StockLog.count", 1 do
      post inventory_stock_in_url, params: {
        stock_log: {
          barcode: @variant.barcode,
          quantity: 5,
          supplier: "Test Supplier",
          note: "Test stock in"
        }
      }
    end

    @variant.reload
    assert_equal 15, @variant.stock # 10 + 5
    assert_redirected_to inventory_stock_in_path(barcode: @variant.barcode)
    assert_match /입고 완료/, flash[:notice]
  end

  # POST /inventory/stock_in - Invalid barcode
  test "should fail stock_in with invalid barcode" do
    post inventory_stock_in_url, params: {
      stock_log: {
        barcode: "INVALID",
        quantity: 5
      }
    }

    assert_redirected_to root_path
    assert_match /바코드를 찾을 수 없습니다/, flash[:alert]
  end

  # GET /inventory/stock_out
  test "should get stock_out" do
    get inventory_stock_out_url
    assert_response :success
  end

  # POST /inventory/stock_out - Success
  test "should create stock_out successfully" do
    assert_difference "StockLog.count", 1 do
      post inventory_stock_out_url, params: {
        stock_log: {
          barcode: @variant.barcode,
          quantity: 3,
          note: "Test stock out"
        }
      }
    end

    @variant.reload
    assert_equal 7, @variant.stock # 10 - 3
    assert_redirected_to inventory_stock_out_path(barcode: @variant.barcode)
    assert_match /출고 완료/, flash[:notice]
  end

  # POST /inventory/stock_out - Insufficient stock
  test "should fail stock_out with insufficient stock" do
    post inventory_stock_out_url, params: {
      stock_log: {
        barcode: @variant.barcode,
        quantity: 20 # More than available (10)
      }
    }

    assert_response :unprocessable_entity
    assert_match /재고 부족/, flash[:alert]
  end

  # GET /inventory/history
  test "should get history" do
    get inventory_history_url
    assert_response :success
  end

  # GET /inventory/history with variant_id
  test "should get history for specific variant" do
    # Create some stock logs
    @variant.stock_logs.create!(log_type: "in", quantity: 5)
    @variant.stock_logs.create!(log_type: "out", quantity: 2)

    get inventory_history_url, params: { variant_id: @variant.id }
    assert_response :success
  end

  # POST /inventory/find_variant - Success (AJAX)
  test "should find variant by barcode via JSON" do
    post inventory_find_variant_url, params: { barcode: @variant.barcode }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal @variant.id, json["variant"]["id"]
    assert_equal @product.id, json["product"]["id"]
    assert_equal 10, json["stock_info"]["current_stock"]
    assert_equal "정상", json["stock_info"]["status"]
  end

  # POST /inventory/find_variant - Not found (AJAX)
  test "should return 404 for non-existent barcode via JSON" do
    post inventory_find_variant_url, params: { barcode: "NONEXISTENT" }, as: :json

    assert_response :not_found
    json = JSON.parse(response.body)
    assert_match /찾을 수 없습니다/, json["error"]
  end

  # POST /inventory/find_variant - Low stock alert
  test "should show low stock alert in JSON response" do
    @variant.update(stock: 4, min_stock: 5) # Low stock

    post inventory_find_variant_url, params: { barcode: @variant.barcode }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert json["stock_info"]["is_low_stock"]
    assert_equal "재고 부족", json["stock_info"]["status"]
    assert_equal 1, json["alerts"].size
    assert_equal "warning", json["alerts"].first["type"]
  end

  # POST /inventory/find_variant - Out of stock alert
  test "should show out of stock alert in JSON response" do
    @variant.update(stock: 0)

    post inventory_find_variant_url, params: { barcode: @variant.barcode }, as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert json["stock_info"]["is_out_of_stock"]
    assert_equal "품절", json["stock_info"]["status"]
    assert_equal 1, json["alerts"].size
    assert_equal "danger", json["alerts"].first["type"]
  end
end
