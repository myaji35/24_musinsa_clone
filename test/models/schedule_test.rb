require "test_helper"

class ScheduleTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:jieum)
    @supplier = suppliers(:one)
    @date = Date.new(2026, 11, 30)
  end

  def feed(from = @date, to = @date + 1, supplier: nil)
    Schedule::Feed.new(@account, from: from, to: to, supplier: supplier).call
  end

  test "automatic deliveries reflect source changes and isolate accounts" do
    order = @supplier.purchase_orders.create!(status: "submitted", expected_delivery_date: @date)
    other = accounts(:other).suppliers.create!(name: "외부", phone: "010")
    other.purchase_orders.create!(status: "confirmed", expected_delivery_date: @date)
    @account.schedule_events.create!(title: "다음 달", starts_on: @date + 1)
    accounts(:other).schedule_events.create!(title: "숨김", starts_on: @date)
    items = feed
    assert_equal [ "입고 예정 #{order.order_number}", "다음 달" ], items.map(&:title)
    assert_equal Rails.application.routes.url_helpers.purchase_order_path(order), items.first.source_path
    assert_equal 1, feed(@date, @date).size
    assert_equal [ "다음 달" ], feed(@date + 1, @date + 1).map(&:title)
    order.update!(status: "received")
    assert_equal [ "다음 달" ], feed.map(&:title)
    assert_empty feed(supplier: other)
  end

  test "receipts consume sales FIFO and feed uses outstanding remaining amount" do
    2.times do |i|
      @account.ledger_entries.create!(supplier: @supplier, entry_type: "sale", amount: 1000, occurred_on: @date - 2 + i, due_on: @date + i)
    end
    @account.ledger_entries.create!(supplier: @supplier, entry_type: "receipt", amount: 1250, occurred_on: Date.current)
    @account.ledger_entries.create!(supplier: @supplier, entry_type: "purchase", amount: 100, occurred_on: @date, due_on: @date)
    items = feed
    assert_equal [ "지급 예정 #{@supplier.name} 100원", "수금 예정 #{@supplier.name} 750원" ], items.map(&:title)
    assert_equal [ @date, @date + 1 ], items.map(&:starts_on)
    assert items.all? { |item| item.source_path == Rails.application.routes.url_helpers.workspace_ledger_partner_path(@supplier) }
    @account.ledger_entries.create!(supplier: @supplier, entry_type: "receipt", amount: 750, occurred_on: Date.current)
    assert_equal 1, feed.size
  end

  test "payments remove settled purchases and show only the remaining payable" do
    due_on = Date.current + 3
    @account.ledger_entries.create!(supplier: @supplier, entry_type: "purchase", amount: 1_000_000, occurred_on: Date.current, due_on: due_on)
    payment = @account.ledger_entries.create!(supplier: @supplier, entry_type: "payment", amount: 1_000_000, occurred_on: Date.current)
    assert_empty feed(due_on, due_on)

    payment.update!(amount: 400_000)
    items = feed(due_on, due_on)
    assert_equal [ "지급 예정 #{@supplier.name} 600,000원" ], items.map(&:title)
    assert_equal [ due_on ], items.map(&:starts_on)
  end

  test "validations use Korean messages and reject foreign suppliers" do
    event = @account.schedule_events.new
    assert_not event.valid?
    assert_includes event.errors.map(&:message), "제목을 입력해 주세요"
    assert_includes event.errors.map(&:message), "일자를 입력해 주세요"
    event.assign_attributes(title: "약속", starts_on: @date, supplier: @supplier, account: accounts(:other))
    assert_not event.valid?
    assert_includes event.errors.map(&:message), "거래처와 계정이 일치하지 않습니다"
  end
end
