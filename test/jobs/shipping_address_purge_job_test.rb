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
    assert_equal expired.address1, order.shipping_record.address1
    assert_equal expired.address1, order.delivery_address.address1
    [ future, consented, unscheduled ].each { |address| assert ShippingAddress.exists?(address.id) }
    assert_equal 0, ShippingAddressPurgeJob.perform_now
  end
  test "사본 생성 실패 시 해당 주소는 보존하고 다음 주소를 처리한다" do
    failed = shipping_addresses(:one)
    failed.update!(purge_after: 1.second.ago)
    next_address = failed.dup
    next_address.save!
    first = orders(:one)
    second = orders(:two)
    first.update!(shipping_address: failed)
    second.update!(shipping_address: failed)
    # 두 번째 사본에서 실패시켜 첫 번째 사본도 롤백되는지 확인한다.
    OrderShippingRecord.connection.execute(<<~SQL)
      CREATE TRIGGER reject_shipping_snapshot BEFORE INSERT ON order_shipping_records
      WHEN NEW.order_id = #{second.id}
      BEGIN SELECT RAISE(ABORT, 'snapshot failed'); END
    SQL
    assert_equal 1, ShippingAddressPurgeJob.perform_now
    assert ShippingAddress.exists?(failed.id)
    assert_not ShippingAddress.exists?(next_address.id)
    assert_equal failed.id, first.reload.shipping_address_id
    assert_nil first.shipping_record
  ensure
    OrderShippingRecord.connection.execute("DROP TRIGGER IF EXISTS reject_shipping_snapshot")
  end
end
