require "test_helper"

class OrderShippingRecordPurgeJobTest < ActiveJob::TestCase
  test "보관 기한이 지난 기록만 파기한다" do
    freeze_time do
      first = orders(:one)
      second = orders(:two)
      [ first, second ].each { |order| order.update!(shipping_address: shipping_addresses(:one)) }
      expired = OrderShippingRecord.snapshot_for!(first)
      future = OrderShippingRecord.snapshot_for!(second)
      expired.update!(retain_until: Time.current)
      future.update!(retain_until: 1.second.from_now)
      assert_equal 1, OrderShippingRecordPurgeJob.perform_now
      assert_not OrderShippingRecord.exists?(expired.id)
      assert OrderShippingRecord.exists?(future.id)
      assert_equal 0, OrderShippingRecordPurgeJob.perform_now
    end
  end
end
