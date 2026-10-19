require "test_helper"

class ShippingAddressPurgeJobTest < ActiveJob::TestCase
  test "만료된 비동의 배송지만 파기하고 주문은 보존한다" do
    expired = shipping_addresses(:one)
    expired.update!(purge_after: 1.second.ago)
    future = expired.dup
    future.update!(purge_after: 1.day.from_now)
    consented = expired.dup
    consented.update!(save_consent: true)
    unscheduled = expired.dup
    unscheduled.update!(purge_after: nil)
    order = orders(:one)
    order.update!(shipping_address: expired)

    assert_no_difference "Order.count" do
      assert_difference "ShippingAddress.count", -1 do
        assert_equal 1, ShippingAddressPurgeJob.perform_now
      end
    end
    assert_nil order.reload.shipping_address_id
    [ future, consented, unscheduled ].each { |address| assert ShippingAddress.exists?(address.id) }
    assert_equal 0, ShippingAddressPurgeJob.perform_now
  end
end
