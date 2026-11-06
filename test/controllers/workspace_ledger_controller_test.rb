require "test_helper"

class WorkspaceLedgerControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in
    @partner = suppliers(:one)
    @entry = accounts(:jieum).ledger_entries.create!(supplier: @partner, entry_type: "sale", occurred_on: Date.current, amount: 12000, due_on: Date.current - 1)
  end

  test "ledger pages and editing" do
    [ workspace_ledger_path, workspace_ledger_new_partner_path, workspace_ledger_partner_path(@partner), workspace_ledger_receivables_path, workspace_ledger_edit_entry_path(@partner, @entry) ].each do |path|
      get path
      assert_response :success
    end
    post workspace_ledger_entries_path(@partner), params: { ledger_entry: { entry_type: "receipt", occurred_on: Date.current, amount: 2000, account_id: accounts(:other).id } }
    assert_redirected_to workspace_ledger_partner_path(@partner)
    assert_equal accounts(:jieum), LedgerEntry.last.account
    assert_equal users(:one), LedgerEntry.last.created_by_user
    patch workspace_ledger_entry_path(@partner, @entry), params: { ledger_entry: { amount: 9000 } }
    assert_equal 9000, @entry.reload.amount
    assert_difference "LedgerEntry.count", -1 do
      delete workspace_ledger_entry_path(@partner, @entry)
    end
  end

  test "blank transaction shows Korean validation messages without attribute names" do
    [ {}, { quantity: 2 }, { unit_price: 100 } ].each do |attributes|
      assert_no_difference "LedgerEntry.count" do
        post workspace_ledger_entries_path(@partner), params: {
          ledger_entry: { entry_type: "sale", occurred_on: "", amount: "" }.merge(attributes)
        }
        assert_response :unprocessable_entity
      end
      assert_includes response.body, "일자를 입력해 주세요"
      assert_equal 1, response.body.scan("금액을 입력해 주세요(수량과 단가를 넣으면 자동 계산)").size
      assert_not_includes response.body, "blank"
      assert_not_includes response.body, "Occurred on"
      assert_not_includes response.body, "Amount"
    end
  end

  test "create partner requires phone" do
    assert_no_difference "Supplier.count" do
      post workspace_ledger_partners_path, params: { supplier: { name: "새 거래처", kind: "sales" } }
      assert_response :unprocessable_entity
      assert_includes response.body, "전화번호를 입력해 주세요"
      assert_not_includes response.body, "blank"
    end
    assert_difference "Supplier.count" do
      post workspace_ledger_partners_path, params: { supplier: { name: "새 거래처", kind: "both", phone: "010", account_id: accounts(:other).id } }
    end
    assert_equal accounts(:jieum), Supplier.last.account
  end

  test "other account partner and ledger return 404 for all operations" do
    foreign_partner = accounts(:other).suppliers.create!(name: "외부 거래처", phone: "010")
    foreign_entry = accounts(:other).ledger_entries.create!(supplier: foreign_partner, entry_type: "sale", amount: 10, occurred_on: Date.current)
    get workspace_ledger_partner_path(foreign_partner)
    assert_response :not_found
    post workspace_ledger_entries_path(foreign_partner), params: { ledger_entry: { entry_type: "sale", amount: 10 } }
    assert_response :not_found
    get workspace_ledger_edit_entry_path(@partner, foreign_entry)
    assert_response :not_found
    patch workspace_ledger_entry_path(@partner, foreign_entry), params: { ledger_entry: { amount: 11 } }
    assert_response :not_found
    delete workspace_ledger_entry_path(@partner, foreign_entry)
    assert_response :not_found
    get suppliers_path
    assert_not_includes response.body, foreign_partner.name
    get supplier_path(foreign_partner)
    assert_response :not_found
    post login_path, params: { email: users(:other).email, password: "TestPassword!2026" }
    get workspace_ledger_path
    assert_response :success
    assert_not_includes response.body, @partner.name
    get workspace_ledger_partner_path(@partner)
    assert_response :not_found
  end

  test "anonymous access requires login" do
    delete logout_path
    get workspace_ledger_path
    assert_redirected_to login_path
  end
end
