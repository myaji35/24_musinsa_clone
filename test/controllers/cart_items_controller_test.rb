require "test_helper"

class CartItemsControllerTest < ActionDispatch::IntegrationTest
  test "로그인 없이 담고 변경하고 삭제한다" do
    post cart_items_path, params: { variant_id: variants(:one).id, quantity: 2 }
    assert_redirected_to cart_path
    assert_equal "장바구니에 담았습니다", flash[:notice]
    get cart_path
    assert_response :success
    assert_select 'div[role="group"][aria-label=?]', "#{variants(:one).product.name} 수량" do
      assert_select 'button[aria-label="수량 줄이기"]:not([disabled])'
      assert_select 'output[aria-live="polite"]', text: "2"
      assert_select 'button[aria-label="수량 늘리기"]:not([disabled])'
    end
    assert_select 'div[class~="aspect-[2/3]"]', count: 1
    patch cart_item_path(variants(:one)), params: { quantity: 99 }
    get cart_path
    assert_select 'output[aria-live="polite"]', text: "99"
    assert_select 'button[aria-label="수량 늘리기"][disabled]'
    delete cart_item_path(variants(:one))
    get cart_path
    assert_includes response.body, "장바구니가 비어 있습니다"
  end

  test "수량을 변경하면 장바구니에 반영하고 안내한다" do
    post cart_items_path, params: { variant_id: variants(:one).id }
    get cart_path
    assert_select 'button[aria-label="수량 줄이기"][disabled]'

    patch cart_item_path(variants(:one)), params: { quantity: 2 }
    assert_redirected_to cart_path
    follow_redirect!
    assert_select 'output[aria-live="polite"]', text: "2"
    assert_select '[role="status"]', text: "수량을 변경했습니다"
  end

  test "옵션 없이 담으면 상품 목록으로 돌아가 안내한다" do
    post cart_items_path

    assert_redirected_to products_path
    assert_equal "색상·사이즈를 선택해 주세요", flash[:alert]
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
