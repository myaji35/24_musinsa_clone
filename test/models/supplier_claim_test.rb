require "test_helper"

class SupplierClaimTest < ActiveSupport::TestCase
  test "validates type status description and supplier ownership" do
    claim = SupplierClaim.new(supplier: suppliers(:one), claim_type: "other", description: "확인 요청")
    assert claim.valid?
    claim.claim_type = "invalid"
    claim.status = "invalid"
    assert_not claim.valid?
    assert claim.errors[:claim_type].any?
    assert claim.errors[:status].any?
    claim.claim_type = "other"
    claim.status = "open"
    claim.description = ""
    assert_not claim.valid?
  end

  test "rejects purchase orders and variants from another supplier" do
    products(:two).update!(supplier: suppliers(:two))
    order = PurchaseOrder.create!(supplier: suppliers(:two), status: "submitted")
    claim = SupplierClaim.new(supplier: suppliers(:one), claim_type: "defective", description: "불량", purchase_order: order, variant: variants(:two))
    assert_not claim.valid?
    assert claim.errors[:purchase_order].any?
    assert claim.errors[:variant].any?
    claim.supplier = suppliers(:two)
    assert claim.valid?
  end
end
