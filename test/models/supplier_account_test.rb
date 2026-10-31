require "test_helper"

class SupplierAccountTest < ActiveSupport::TestCase
  test "normalizes email and rejects duplicate emails" do
    account = SupplierAccount.create!(supplier: suppliers(:one), email: " Partner@Example.com ", password: "Password!2026")
    assert_equal "partner@example.com", account.email
    duplicate = SupplierAccount.new(supplier: suppliers(:two), email: "PARTNER@example.com", password: "Password!2026")
    assert_not duplicate.valid?
    assert duplicate.errors[:email].any?
    assert account.authenticate("Password!2026")
  end

  test "rejects passwords shorter than 10 characters" do
    account = SupplierAccount.new(supplier: suppliers(:one), email: "short@example.com", password: "Short!1")
    assert_not account.valid?
    assert account.errors.of_kind?(:password, :too_short)
  end
end
