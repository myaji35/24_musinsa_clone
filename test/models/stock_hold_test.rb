require "test_helper"

class StockHoldTest < ActiveSupport::TestCase
  test "필수 값과 상태 및 양의 정수 수량을 검증한다" do
    hold = StockHold.new
    assert_not hold.valid?
    hold.assign_attributes(variant: variants(:one), quantity: 1, token: "검증", expires_at: 10.minutes.from_now)
    assert hold.valid?
    [ 0, -1, 1.5 ].each do |quantity|
      hold.quantity = quantity
      assert_not hold.valid?
    end
    hold.quantity = 1
    hold.status = "invalid"
    assert_not hold.valid?
  end

  test "만료 범위는 기한에 도달한 held만 포함한다" do
    travel_to Time.zone.local(2026, 11, 10, 12) do
      hold = StockHold.create!(variant: variants(:one), quantity: 1, token: "만료", expires_at: Time.current)
      assert_includes StockHold.expired, hold
      hold.update!(status: "converted")
      assert_not_includes StockHold.expired, hold
      hold.update!(status: "held", expires_at: 1.second.from_now)
      assert_not_includes StockHold.expired, hold
    end
  end
end
