require "test_helper"

class AccountTest < ActiveSupport::TestCase
  class ScopedUser < ApplicationRecord
    self.table_name = "users"
    include AccountScoped
  end

  test "primary lookup and safe lookup" do
    assert_equal accounts(:jieum), Account.primary
    accounts(:jieum).update!(slug: "renamed")
    assert_nil Account.primary_or_nil
    assert_raises(ActiveRecord::RecordNotFound) { Account.primary }
  end

  test "account scoped users require membership and filter explicitly" do
    model = ScopedUser
    assert_equal [ users(:one).id, users(:two).id ].sort, model.for_account(accounts(:jieum)).pluck(:id).sort
    assert_equal [ users(:other).id ], model.for_account(accounts(:other)).pluck(:id)
    assert_equal User.count, model.count
    assert_not model.new.valid?
    assert model.new(account: accounts(:other)).valid?
  end
end
