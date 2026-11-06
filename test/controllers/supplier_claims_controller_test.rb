require "test_helper"

class SupplierClaimsControllerTest < ActionDispatch::IntegrationTest
  test "클레임 거래처 목록과 저장은 현재 계정으로 제한된다" do
    sign_in
    foreign = Supplier.create!(account: accounts(:other), name: "외부 거래처", phone: "02-9999-9999", active: true)
    get new_supplier_claim_path
    assert_response :success
    assert_select "select[name='supplier_claim[supplier_id]'] option[value='#{foreign.id}']", count: 0
    assert_select "select[name='supplier_claim[supplier_id]'] option[value='#{suppliers(:one).id}']", count: 1

    assert_no_difference "SupplierClaim.count" do
      post supplier_claims_path, params: { supplier_claim: { supplier_id: foreign.id } }
    end
    assert_response :unprocessable_entity
  end
end
