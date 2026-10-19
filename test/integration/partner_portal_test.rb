require "test_helper"

class PartnerPortalTest < ActionDispatch::IntegrationTest
  setup do
    @supplier = suppliers(:one)
    @other = suppliers(:two)
    @account = SupplierAccount.create!(supplier: @supplier, email: "partner@example.com", password: "PartnerPass!2026")
    products(:one).update!(supplier: @supplier)
    products(:two).update!(supplier: @other)
    @order = PurchaseOrder.create!(supplier: @supplier, status: "submitted", confirmation_token_expires_at: 1.day.ago)
    @foreign_order = PurchaseOrder.create!(supplier: @other, status: "submitted")
    @claim = @supplier.supplier_claims.create!(claim_type: "other", description: "확인 요청")
    @foreign_claim = @other.supplier_claims.create!(claim_type: "other", description: "다른 거래처")
  end

  def partner_login
    post partner_login_path, params: { email: " PARTNER@example.com ", password: "PartnerPass!2026" }
    assert_redirected_to partner_root_path
  end

  test "requires separate supplier authentication" do
    get partner_root_path
    assert_redirected_to partner_login_path
    sign_in
    get partner_root_path
    assert_redirected_to partner_login_path
    partner_login
    assert @account.reload.last_sign_in_at
    get suppliers_path
    assert_redirected_to login_path
    get partner_root_path
    assert_response :success
    assert_select "nav", text: /대시보드/
    assert_select "a[href=?]", suppliers_path, count: 0
  end

  test "rejects invalid password and inactive accounts or suppliers with same error" do
    post partner_login_path, params: { email: @account.email, password: "wrong" }
    assert_response :unprocessable_entity
    assert_includes response.body, "이메일 또는 비밀번호가 올바르지 않습니다."
    @account.update!(active: false)
    post partner_login_path, params: { email: @account.email, password: "PartnerPass!2026" }
    assert_response :unprocessable_entity
    @account.update!(active: true)
    @supplier.update!(active: false)
    post partner_login_path, params: { email: @account.email, password: "PartnerPass!2026" }
    assert_response :unprocessable_entity
  end

  test "invalidates existing sessions when account or supplier is disabled" do
    partner_login
    @account.update!(active: false)
    get partner_root_path
    assert_redirected_to partner_login_path
    @account.update!(active: true)
    get partner_root_path
    assert_redirected_to partner_login_path
    partner_login
    @supplier.update!(active: false)
    get partner_root_path
    assert_redirected_to partner_login_path
  end

  test "scopes orders claims and inventory to supplier" do
    partner_login
    get partner_purchase_order_path(@foreign_order)
    assert_response :not_found
    post confirm_partner_purchase_order_path(@foreign_order)
    assert_response :not_found
    get partner_claim_path(@foreign_claim)
    assert_response :not_found
    patch partner_claim_path(@foreign_claim), params: { supplier_claim: { supplier_response: "답변" } }
    assert_response :not_found
    get partner_inventory_index_path
    assert_response :success
    assert_includes response.body, products(:one).name
    assert_not_includes response.body, products(:two).name
    assert_includes response.body, "재고 부족"
    variants(:one).update!(stock: 10)
    get partner_inventory_index_path(low: 1)
    assert_not_includes response.body, products(:one).name
  end

  test "lists orders hides drafts and confirms submitted orders without token" do
    draft = @supplier.purchase_orders.create!(status: "draft")
    partner_login
    get partner_purchase_orders_path
    assert_response :success
    assert_includes response.body, @order.order_number
    assert_not_includes response.body, @foreign_order.order_number
    assert_not_includes response.body, draft.order_number
    get partner_purchase_order_path(draft)
    assert_response :not_found
    get partner_purchase_order_path(@order)
    assert_response :success
    post confirm_partner_purchase_order_path(@order)
    assert_redirected_to partner_purchase_order_path(@order)
    assert_equal "confirmed", @order.reload.status
    confirmed_at = @order.confirmed_at
    post confirm_partner_purchase_order_path(@order)
    assert_equal confirmed_at, @order.reload.confirmed_at
  end

  test "answers claims ignores status injection and cannot modify resolved claims" do
    partner_login
    get partner_claims_path(status: "open")
    assert_response :success
    get partner_claim_path(@claim)
    assert_response :success
    patch partner_claim_path(@claim), params: { supplier_claim: { supplier_response: "" } }
    assert_response :unprocessable_entity
    patch partner_claim_path(@claim), params: { supplier_claim: { supplier_response: "교환하겠습니다", status: "resolved", supplier_id: @other.id } }
    assert_redirected_to partner_claim_path(@claim)
    assert_equal "answered", @claim.reload.status
    assert_equal @supplier.id, @claim.supplier_id
    assert @claim.responded_at
    @claim.update!(status: "resolved", resolved_at: Time.current)
    patch partner_claim_path(@claim), params: { supplier_claim: { supplier_response: "변경" } }
    assert_equal "교환하겠습니다", @claim.reload.supplier_response
    assert_equal "resolved", @claim.status
  end

  test "logout clears supplier session" do
    partner_login
    delete partner_logout_path
    assert_redirected_to partner_login_path
    get partner_root_path
    assert_redirected_to partner_login_path
  end

  test "admin creates resolves claims and issues toggles accounts" do
    sign_in
    get supplier_claims_path
    assert_response :success
    get new_supplier_claim_path
    assert_response :success
    assert_difference "SupplierClaim.count", 1 do
      post supplier_claims_path, params: { supplier_claim: { supplier_id: @supplier.id, claim_type: "defective", description: "불량 확인", quantity: 2 } }
    end
    claim = SupplierClaim.order(:id).last
    assert_equal users(:one), claim.created_by_user
    get supplier_claim_path(claim)
    assert_response :success
    patch resolve_supplier_claim_path(claim)
    assert_equal "resolved", claim.reload.status
    assert claim.resolved_at
    assert_difference "SupplierAccount.count", 1 do
      post supplier_supplier_accounts_path(@supplier), params: { supplier_account: { email: "new@example.com", name: "담당자", password: "NewPassword!2026" } }
    end
    account = SupplierAccount.find_by!(email: "new@example.com")
    assert account.authenticate("NewPassword!2026")
    get supplier_path(@supplier)
    assert_response :success
    assert_not_includes response.body, "NewPassword!2026"
    patch toggle_supplier_supplier_account_path(@supplier, account)
    assert_not account.reload.active?
    patch toggle_supplier_supplier_account_path(@other, account)
    assert_response :not_found
  end
end
