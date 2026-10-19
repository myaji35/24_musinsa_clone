require "test_helper"

class CartTest < ActiveSupport::TestCase
  test "옵션과 수량을 정리하고 합계를 계산한다" do
    cart = Cart.new(variants(:one).id.to_s => 2, "999999999" => 3)
    assert_equal 2, cart.count
    assert_equal products(:one).price * 2, cart.total
    assert_equal products(:one), cart.items.first.product
    assert_equal cart.total, cart.items.first.line_total
    cart.add(variants(:one).id, 200)
    assert_equal 99, cart.count
    cart.update(variants(:one).id, -2)
    assert_equal 1, cart.count
    cart.add(-1, 3)
    assert_equal 1, cart.count
    cart.remove(variants(:one).id)
    assert_empty cart.items
  end
end
