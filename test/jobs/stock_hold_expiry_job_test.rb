require "test_helper"

class StockHoldExpiryJobTest < ActiveSupport::TestCase
  test "잡은 만료 홀드를 해제한다" do
    hold = Inventory::StockHoldService.reserve(variant_id: variants(:one).id, quantity: 2).data
    travel_to hold.expires_at, with_usec: true do
      StockHoldExpiryJob.perform_now
      assert_equal "released", hold.reload.status
      assert_equal 5, variants(:one).reload.stock
    end
  end
end
