require "test_helper"

class Inventory::StockHoldServiceTest < ActiveSupport::TestCase
  setup do
    @variant = variants(:one)
  end

  test "예약은 재고를 한 번 차감하고 출고를 기록한다" do
    result = Inventory::StockHoldService.reserve(variant_id: @variant.id, quantity: 2, source: "broadcast")
    assert result.success?
    assert_equal 3, @variant.reload.stock
    assert_equal "broadcast", result.data.source
    assert_in_delta 10.minutes.from_now, result.data.expires_at, 1
    assert_equal 2, StockLog.where(note: "방송 홀드 #{result.data.token}", log_type: "out").sum(:quantity)
  end

  test "부족과 잘못된 수량은 재고와 이력을 변경하지 않는다" do
    [ 6, 0, -1, 1.5 ].each do |quantity|
      assert_no_difference [ "StockHold.count", "StockLog.count" ] do
        result = Inventory::StockHoldService.reserve(variant_id: @variant.id, quantity: quantity)
        assert result.failure?
      end
    end
    assert_equal 5, @variant.reload.stock
  end

  test "해제는 한 번만 재고를 복원한다" do
    hold = Inventory::StockHoldService.reserve(variant_id: @variant.id, quantity: 2).data
    assert_equal true, Inventory::StockHoldService.release(hold.token).data
    assert_equal false, Inventory::StockHoldService.release(hold.token).data
    assert_equal false, Inventory::StockHoldService.release("없음").data
    assert_equal "released", hold.reload.status
    assert_equal 5, @variant.reload.stock
    assert_equal 1, StockLog.where(note: "방송 홀드 해제 #{hold.token}").count
  end

  test "만료 해제는 기한에 도달한 홀드만 복원한다" do
    travel_to Time.zone.local(2026, 11, 10, 12) do
      expired = Inventory::StockHoldService.reserve(variant_id: @variant.id, quantity: 1).data
      active = Inventory::StockHoldService.reserve(variant_id: @variant.id, quantity: 1, ttl: 20.minutes).data
      travel 10.minutes
      assert_equal 1, Inventory::StockHoldService.release_expired.data
      assert_equal 0, Inventory::StockHoldService.release_expired.data
      assert_equal "released", expired.reload.status
      assert_equal "held", active.reload.status
      assert_equal 4, @variant.reload.stock
    end
  end
end
