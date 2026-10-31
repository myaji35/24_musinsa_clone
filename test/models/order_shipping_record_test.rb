require "test_helper"

class OrderShippingRecordTest < ActiveSupport::TestCase
  test "배송지를 암호화하고 주문 생성일부터 설정된 연수만큼 보관한다" do
    order = orders(:one)
    address = shipping_addresses(:one)
    order.update!(shipping_address: address)
    record = OrderShippingRecord.snapshot_for!(order)
    assert_equal order.created_at + Rails.configuration.x.order_record_retention_years.years, record.retain_until
    %w[recipient_name phone postal_code address1 address2 country_code].each do |field|
      if address.public_send(field).nil?
        assert_nil record.reload.public_send(field)
      else
        assert_equal address.public_send(field), record.reload.public_send(field)
      end
    end
    raw = OrderShippingRecord.connection.select_value("select address1 from order_shipping_records where id=#{record.id}")
    assert_not_equal address.address1, raw
    assert_not_includes raw, address.address1
    assert_equal address, order.delivery_address
    assert_no_difference "OrderShippingRecord.count" do
      assert_equal record, OrderShippingRecord.snapshot_for!(order)
    end
    address.update!(address1: "변경된 주소")
    assert_equal record.address1, OrderShippingRecord.snapshot_for!(order).address1
    address.destroy!
    assert_equal record, order.reload.delivery_address
    assert_equal record, OrderShippingRecord.snapshot_for!(order)
  end

  test "배송지가 없는 주문은 사본을 만들지 않는다" do
    order = orders(:one)
    order.update!(shipping_address: nil)
    assert_nil OrderShippingRecord.snapshot_for!(order)
    assert_nil order.delivery_address
  end
end
