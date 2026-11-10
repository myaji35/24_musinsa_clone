require "test_helper"

class UnpaidOrderExpiryJobTest < ActiveSupport::TestCase
  setup do
    @original_flag = ENV["ORDER_AUTO_CANCEL_ENABLED"]
    @original_days = ENV["PAYOUT_DUE_DAYS"]
    ENV["PAYOUT_DUE_DAYS"] = "3"
  end

  teardown do
    ENV["ORDER_AUTO_CANCEL_ENABLED"] = @original_flag
    ENV["PAYOUT_DUE_DAYS"] = @original_days
  end

  test "기본 비활성화이면 취소하지 않는다" do
    ENV.delete("ORDER_AUTO_CANCEL_ENABLED")
    order = orders(:one)
    order.update!(status: "pending", created_at: 10.days.ago)
    assert_no_difference "StockLog.count" do
      UnpaidOrderExpiryJob.perform_now
    end
    assert_equal "pending", order.reload.status
  end

  test "활성화 시 한국 날짜 기준 기한 지난 pending만 취소하고 복원한다" do
    ENV["ORDER_AUTO_CANCEL_ENABLED"] = "1"
    travel_to Time.utc(2026, 11, 9, 16) do
      overdue = orders(:one)
      overdue.update!(status: "pending", created_at: Time.zone.local(2026, 11, 6, 23))
      due_today = Order.create!(anony_customer: overdue.anony_customer, product: overdue.product,
                               variant: overdue.variant, quantity: 1, total_price: 100,
                               status: "pending", created_at: Time.zone.local(2026, 11, 7))
      future = Order.create!(anony_customer: overdue.anony_customer, product: overdue.product,
                            variant: overdue.variant, quantity: 1, total_price: 100, status: "pending")
      paid = orders(:two)
      paid.update_columns(status: "paid", created_at: 10.days.ago)
      stock = overdue.variant.stock
      UnpaidOrderExpiryJob.perform_now
      UnpaidOrderExpiryJob.perform_now
      assert_equal "cancelled", overdue.reload.status
      assert_equal stock + overdue.quantity, overdue.variant.reload.stock
      assert_equal 1, StockLog.where(order_id: overdue.id, log_type: "in").count
      assert_equal "pending", due_today.reload.status
      assert_equal "pending", future.reload.status
      assert_equal "paid", paid.reload.status
    end
  end
end
