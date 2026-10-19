require "test_helper"

class OrderTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "수량과 주문 상태를 검증한다" do
    order = orders(:one)
    order.assign_attributes(quantity: 0, status: "invalid")
    assert_not order.valid?
    assert order.errors[:quantity].present?
    assert order.errors[:status].present?
  end

  test "생성 시 주문번호와 취향 갱신 작업을 한 번 생성한다" do
    order = Order.new(anony_customer: anony_customers(:one), product: products(:one), variant: variants(:one), quantity: 1, total_price: 19900)
    assert_enqueued_with(job: UpdatePreferenceTagsJob) { order.save! }
    assert_match /\AORD-\d{8}-[0-9A-F]{8}\z/, order.order_number
    number = order.order_number
    assert_no_enqueued_jobs(only: UpdatePreferenceTagsJob) { order.update!(status: "paid") }
    assert_equal number, order.reload.order_number
  end

  test "주문 완료 시 생성 작업이 학습한 취향 태그를 중복 증가시키지 않는다" do
    customer = anony_customers(:one)
    product = products(:one)
    product.update!(ai_attributes: { mood: [ "minimal" ], tpo: [ "daily" ], fit_style: "regular", material_feel: "soft" })
    expected_tags = customer.preference_tags.deep_dup
    [ product.category, product.brand, "mood:minimal", "tpo:daily", "fit:regular", "material:soft" ].each do |tag|
      expected_tags[tag] = expected_tags.fetch(tag, 0) + 1
    end

    order = nil
    perform_enqueued_jobs(only: UpdatePreferenceTagsJob) do
      order = Order.create!(anony_customer: customer, product: product, variant: variants(:one), quantity: 3, total_price: 59700)
    end
    assert_equal expected_tags, customer.reload.preference_tags

    assert_no_enqueued_jobs(only: UpdatePreferenceTagsJob) { assert order.complete! }
    assert_equal "delivered", order.reload.status
    assert_equal expected_tags, customer.reload.preference_tags
  end

  test "상태 범위는 해당 주문만 반환한다" do
    paid = orders(:one)
    delivered = orders(:two)
    assert_includes Order.paid, paid
    assert_not_includes Order.paid, delivered
    assert_includes Order.delivered, delivered
    assert_not_includes Order.pending, paid
  end
  test "완료와 직접 상태 변경은 배송 완료 시각 기준 90일 파기를 예약한다" do
    [ :complete!, :update! ].each do |method|
      order = orders(:one)
      order.update!(status: "paid", shipping_address: shipping_addresses(:one))
      freeze_time do
        method == :complete! ? order.complete! : order.update!(status: "delivered")
        assert_equal Time.current, order.reload.delivered_at
        assert_equal order.delivered_at + 90.days, order.shipping_address.reload.purge_after
      end
      delivered_at = order.delivered_at
      travel 1.day do
        order.update!(quantity: 3)
        assert_equal delivered_at, order.reload.delivered_at
      end
    end
  end

  test "동의 배송지는 주문 완료 후에도 파기 예정일이 없다" do
    address = shipping_addresses(:one)
    address.update!(save_consent: true, consented_at: Time.current)
    order = orders(:one)
    order.update!(shipping_address: address)
    order.complete!
    assert_not_nil order.reload.delivered_at
    assert_nil address.reload.purge_after
  end

  test "같은 배송지의 주문이 모두 종결된 뒤에만 파기를 예약한다" do
    address = shipping_addresses(:one)
    first = orders(:one)
    second = orders(:two)
    first.update!(status: "paid", shipping_address: address)
    second.update!(status: "paid", shipping_address: address)

    first.complete!
    assert_nil address.reload.purge_after

    freeze_time do
      second.update!(status: "cancelled")
      assert_equal Time.current + 90.days, address.reload.purge_after
    end
  end

  test "취소만 된 주문의 배송지도 파기를 예약한다" do
    address = shipping_addresses(:one)
    order = orders(:one)
    order.update!(status: "pending", shipping_address: address)
    freeze_time do
      order.update!(status: "cancelled")
      assert_nil order.reload.delivered_at
      assert_equal Time.current + 90.days, address.reload.purge_after
    end
  end
end
