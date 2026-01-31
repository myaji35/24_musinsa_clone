require "test_helper"

class InventoryControllerTest < ActionDispatch::IntegrationTest
  test "should get scan" do
    get inventory_scan_url
    assert_response :success
  end

  test "should get stock_in" do
    get inventory_stock_in_url
    assert_response :success
  end

  test "should get stock_out" do
    get inventory_stock_out_url
    assert_response :success
  end

  test "should get history" do
    get inventory_history_url
    assert_response :success
  end
end
