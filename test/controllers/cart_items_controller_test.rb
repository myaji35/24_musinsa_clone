require "test_helper"

class CartItemsControllerTest < ActionDispatch::IntegrationTest
  test "로그인 없이 담고 변경하고 삭제한다" do
    post cart_items_path, params: { variant_id: variants(:one).id, quantity: 2 }
    assert_redirected_to cart_path
    assert_equal "장바구니에 담았습니다", flash[:notice]
    get cart_path
    assert_response :success
    assert_select 'input[name="quantity"][value="2"]'
    patch cart_item_path(variants(:one)), params: { quantity: 99 }
    get cart_path
    assert_select 'input[name="quantity"][value="99"]'
    delete cart_item_path(variants(:one))
    get cart_path
    assert_includes response.body, "장바구니가 비어 있습니다"
  end

  test "바로구매는 주문서로 이동하고 없는 옵션은 버린다" do
    post cart_items_path, params: { variant_id: -1 }
    get cart_path
    assert_includes response.body, "장바구니가 비어 있습니다"
    post cart_items_path, params: { variant_id: variants(:one).id, buy_now: "1" }
    assert_redirected_to new_checkout_path
    assert_nil flash[:notice]
  end
end
