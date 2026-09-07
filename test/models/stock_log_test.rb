require "test_helper"

class StockLogTest < ActiveSupport::TestCase
  setup do
    @variant = variants(:one)
  end

  test "유효하지 않은 유형과 수량은 재고를 변경하지 않는다" do
    [ { log_type: "invalid", quantity: 2 }, { log_type: "in", quantity: 0 } ].each do |attributes|
      log = @variant.stock_logs.build(attributes)
      assert_no_difference [ "StockLog.count", "@variant.reload.stock" ] do
        assert_not log.save
      end
    end
  end

  test "입고 생성은 재고를 정확히 한 번 증가시키고 수정은 변경하지 않는다" do
    log = nil
    assert_difference "@variant.reload.stock", 3 do
      log = @variant.stock_logs.create!(log_type: "in", quantity: 3)
    end
    assert_no_difference "@variant.reload.stock" do
      log.update!(note: "입고 메모 수정")
      log.reload
    end
  end

  test "출고 생성은 재고를 정확히 한 번 감소시키고 수정은 변경하지 않는다" do
    log = nil
    assert_difference "@variant.reload.stock", -2 do
      log = @variant.stock_logs.create!(log_type: "out", quantity: 2)
    end
    assert_no_difference "@variant.reload.stock" do
      log.update!(note: "출고 메모 수정")
    end
  end

  test "입출고 및 기간 범위로 이력을 조회한다" do
    travel_to Time.zone.local(2026, 9, 7, 12) do
      incoming = @variant.stock_logs.create!(log_type: "in", quantity: 3)
      outgoing = @variant.stock_logs.create!(log_type: "out", quantity: 1)
      assert_includes StockLog.stock_in, incoming
      assert_not_includes StockLog.stock_in, outgoing
      assert_includes StockLog.stock_out, outgoing
      assert_not_includes StockLog.stock_out, incoming
      assert_includes StockLog.by_date_range(1.minute.ago, Time.current), incoming
      assert_not_includes StockLog.by_date_range(2.days.ago, 1.day.ago), incoming
    end
  end
end
