require "test_helper"

class WorkspaceScheduleControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in
    @account = accounts(:jieum)
    @event = @account.schedule_events.create!(title: "회의", starts_on: Date.current - 1)
  end

  test "overdue items precede upcoming dates and respect supplier filter" do
    supplier = suppliers(:one)
    @event.update!(supplier: supplier)
    yesterday = Date.current - 1
    %w[done cancelled].each do |status|
      @account.schedule_events.create!(title: "숨김 #{status}", starts_on: yesterday, status: status, supplier: supplier)
    end
    @account.schedule_events.create!(title: "오래된 일정", starts_on: Date.current - 91, supplier: supplier)
    @account.schedule_events.create!(title: "오늘 일정", starts_on: Date.current, supplier: supplier)
    order = supplier.purchase_orders.create!(status: "confirmed", expected_delivery_date: yesterday)
    @account.ledger_entries.create!(supplier: supplier, entry_type: "sale", amount: 1000, occurred_on: yesterday, due_on: yesterday)
    receipt = @account.ledger_entries.create!(supplier: supplier, entry_type: "receipt", amount: 250, occurred_on: yesterday)
    @account.ledger_entries.create!(supplier: supplier, entry_type: "purchase", amount: 500, occurred_on: yesterday, due_on: yesterday)

    get workspace_schedule_path(view: "list", supplier_id: supplier.id)
    assert_response :success
    assert_select "#overdue" do
      assert_select "h2", text: "지난 미완료 4건"
      [ "회의", "입고 지연 #{order.order_number}", "수금 지연 #{supplier.name} 750원", "지급 지연 #{supplier.name} 500원" ].each do |title|
        assert_select "strong", text: title
      end
    end
    assert_operator response.body.index('id="overdue"'), :<, response.body.index("오늘 일정")
    [ "숨김 done", "숨김 cancelled", "오래된 일정" ].each { |title| assert_not_includes response.body, title }
    get workspace_schedule_path(supplier_id: supplier.id)
    assert_select "a[href=?]", workspace_schedule_path(view: "list", supplier_id: supplier.id, anchor: "overdue"), text: "지난 미완료 4건"

    receipt.update!(amount: 1000)
    get workspace_schedule_path(view: "list", supplier_id: supplier.id)
    assert_select "#overdue", text: /수금 지연/, count: 0
    @event.update!(supplier: nil)
    get workspace_schedule_path(view: "list", supplier_id: supplier.id)
    assert_select "#overdue strong", text: "회의", count: 0
  end

  test "pages CRUD completion and Korean errors" do
    [ workspace_schedule_path, workspace_schedule_path(view: "list"), workspace_schedule_new_path, workspace_schedule_edit_path(@event) ].each do |path|
      get path
      assert_response :success
    end
    get workspace_schedule_path
    assert_includes response.body, "지남" unless Date.current.day == 1
    assert_difference "ScheduleEvent.count" do
      post workspace_schedule_path, params: { schedule_event: { title: "납품", starts_on: Date.current, kind: "delivery", account_id: accounts(:other).id } }
    end
    assert_equal @account, ScheduleEvent.last.account
    assert_equal users(:one), ScheduleEvent.last.created_by_user
    patch workspace_schedule_event_path(@event), params: { schedule_event: { title: "변경" } }
    assert_equal "변경", @event.reload.title
    patch workspace_schedule_complete_path(@event)
    assert_equal "done", @event.reload.status
    assert_difference "ScheduleEvent.count", -1 do
      delete workspace_schedule_event_path(@event)
    end
    post workspace_schedule_path, params: { schedule_event: { title: "", starts_on: "" } }
    assert_response :unprocessable_entity
    assert_includes response.body, "제목을 입력해 주세요"
    assert_includes response.body, "일자를 입력해 주세요"
    assert_not_includes response.body, "Starts on"
  end

  test "month boundaries filter and account isolation for every operation" do
    foreign = accounts(:other).schedule_events.create!(title: "외부 일정", starts_on: Date.current)
    partner = accounts(:other).suppliers.create!(name: "외부 거래처", phone: "010")
    partner.purchase_orders.create!(status: "submitted", expected_delivery_date: Date.current, order_number: "FOREIGN-ORDER")
    get workspace_schedule_path
    assert_not_includes response.body, foreign.title
    assert_not_includes response.body, "FOREIGN-ORDER"
    get workspace_schedule_edit_path(foreign)
    assert_response :not_found
    patch workspace_schedule_event_path(foreign), params: { schedule_event: { title: "공격" } }
    assert_response :not_found
    patch workspace_schedule_complete_path(foreign)
    assert_response :not_found
    delete workspace_schedule_event_path(foreign)
    assert_response :not_found
    get workspace_schedule_path(supplier_id: partner.id)
    assert_response :not_found
    post workspace_schedule_path, params: { schedule_event: { title: "공격", starts_on: Date.current, supplier_id: partner.id } }
    assert_response :not_found
    @account.schedule_events.create!(title: "말일 일정", starts_on: "2026-11-30")
    @account.schedule_events.create!(title: "첫날 일정", starts_on: "2026-12-01")
    get workspace_schedule_path(month: "2026-11")
    assert_includes response.body, "말일 일정"
    assert_not_includes response.body, "첫날 일정"
    get workspace_schedule_path(month: "2026-12")
    assert_includes response.body, "첫날 일정"
    assert_not_includes response.body, "말일 일정"
    get workspace_schedule_path(supplier_id: suppliers(:one).id)
    assert_not_includes response.body, "회의"
    delete logout_path
    get workspace_schedule_path
    assert_redirected_to login_path
  end
end
