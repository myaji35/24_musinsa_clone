require "test_helper"

class LedgerTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:jieum)
    @supplier = suppliers(:one)
  end

  def entry(type, amount, **attributes)
    @account.ledger_entries.create!({ supplier: @supplier, entry_type: type, amount: amount, occurred_on: Date.current }.merge(attributes))
  end

  test "balances FIFO and due date boundaries are account scoped" do
    travel_to Time.zone.local(2026, 11, 6, 12) do
      first = entry("sale", 100, occurred_on: Date.current - 5, due_on: Date.current - 1)
      second = entry("sale", 200, occurred_on: Date.current - 4, due_on: Date.current)
      third = entry("sale", 300, occurred_on: Date.current - 3, due_on: Date.current + 7)
      fourth = entry("sale", 400, due_on: Date.current + 8)
      entry("receipt", 150)
      entry("purchase", 500)
      entry("payment", 100)
      entry("adjustment", 20)
      other_supplier = accounts(:other).suppliers.create!(name: @supplier.name, phone: "010")
      accounts(:other).ledger_entries.create!(supplier: other_supplier, entry_type: "sale", amount: 999, occurred_on: Date.current)
      balance = Ledger::Balance.new(@account)
      assert_equal({ receivable: 870, payable: 400 }, balance.totals)
      groups = balance.receivables
      assert_nil groups["예정일 지남"]
      assert_equal [ second, third ], groups["7일 이내"].map { |row| row[:entry] }
      assert_equal [ 150, 300 ], groups["7일 이내"].map { |row| row[:remaining] }
      assert_equal fourth, groups["이후"].first[:entry]
      entry("receipt", 1).destroy!
      entry("sale", 25, occurred_on: first.occurred_on - 1, due_on: Date.current - 2)
      assert_equal 175, Ledger::Balance.new(@account).receivables["7일 이내"].first[:remaining]
      entry("sale", 200, occurred_on: first.occurred_on - 2, due_on: Date.current - 3)
      assert_equal 50, Ledger::Balance.new(@account).receivables["예정일 지남"].first[:remaining]
    end
  end

  test "undated sales consume receipts before later dated sales and negative adjustments reduce debt" do
    entry("sale", 100, occurred_on: Date.current - 2)
    later = entry("sale", 200, occurred_on: Date.current - 1, due_on: Date.current + 1)
    entry("receipt", 120)
    entry("adjustment", -30)
    balance = Ledger::Balance.new(@account, @supplier)
    assert_equal 150, balance.totals[:receivable]
    assert_equal later, balance.receivables["7일 이내"].first[:entry]
    assert_equal 150, balance.receivables["7일 이내"].first[:remaining]
    assert_empty Ledger::Balance.new(accounts(:other), @supplier).partners
  end

  test "payments consume purchases FIFO including undated purchases within each partner" do
    entry("purchase", 100, occurred_on: Date.current - 3)
    settled = entry("purchase", 200, occurred_on: Date.current - 2, due_on: Date.current + 8)
    remaining = entry("purchase", 300, occurred_on: Date.current - 1, due_on: Date.current - 1)
    entry("payment", 350)
    entry("receipt", 999)
    balance = Ledger::Balance.new(@account, @supplier)
    rows = balance.partners.first[:payables_outstanding]
    assert_equal [ remaining ], rows.map { |row| row[:entry] }
    assert_equal 250, rows.first[:remaining]
    assert_equal @supplier, rows.first[:supplier]
    assert_equal "예정일 지남", rows.first[:bucket]
    assert_equal rows, balance.payables["예정일 지남"]
    assert_not_includes rows.map { |row| row[:entry] }, settled
    assert_empty Ledger::Balance.new(accounts(:other), @supplier).payables
  end

  test "validation default amount and supplier account isolation" do
    item = @account.ledger_entries.new(supplier: @supplier, entry_type: "sale", quantity: 3, unit_price: 1200, occurred_on: Date.current)
    assert item.save
    assert_equal 3600, item.amount
    item.account = accounts(:other)
    assert_not item.valid?
    item.account = @account
    item.amount = -10
    assert_not item.valid?
    item.entry_type = "adjustment"
    assert item.valid?
    item.amount = nil
    assert_not item.valid?
  end

  test "amount errors distinguish missing nonnumeric and nonpositive values" do
    item = @account.ledger_entries.new(supplier: @supplier, entry_type: "sale", occurred_on: Date.current)
    { "" => "금액을 입력해 주세요(수량과 단가를 넣으면 자동 계산)",
      "abc" => "금액은 숫자여야 합니다", "0" => "금액은 0보다 커야 합니다",
      "-1" => "금액은 0보다 커야 합니다" }.each do |amount, message|
      item.amount = amount
      assert_not item.valid?
      assert_equal [ message ], item.errors[:amount]
    end
    item.entry_type = "adjustment"
    item.amount = "abc"
    assert_not item.valid?
    assert_equal [ "금액은 숫자여야 합니다" ], item.errors[:amount]
  end

  test "supplier names unique per account and phone required" do
    copy = accounts(:other).suppliers.create!(name: @supplier.name, phone: "010")
    assert copy.persisted?
    assert_not @account.suppliers.new(name: @supplier.name, phone: "010").valid?
    assert_not @account.suppliers.new(name: "전화 없음").valid?
  end

  test "receipt creates exactly one purchase ledger entry in supplier account" do
    order = purchase_orders(:two)
    assert_difference "LedgerEntry.count", 1 do
      assert order.receive!
      assert_not PurchaseOrder.find(order.id).receive!
    end
    item = LedgerEntry.find_by!(source: order)
    assert_equal order.supplier.account, item.account
    assert_equal order.total_amount, item.amount
    assert_equal "purchase", item.entry_type
    assert_equal Date.current, item.occurred_on
    assert_equal "발주 입고 #{order.order_number}", item.item_name
  end

  test "ledger failure rolls back stock and receipt" do
    order = purchase_orders(:two)
    order.purchase_order_items.update_all(unit_price: 0)
    assert_no_difference [ "StockLog.count", "LedgerEntry.count", "variants(:two).reload.stock" ] do
      assert_not order.receive!
    end
    assert_equal "confirmed", order.reload.status
  end
end
