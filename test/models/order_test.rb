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
end
