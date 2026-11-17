class AddPasswordChangeFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :must_change_password, :boolean, default: false, null: false
    add_column :users, :password_changed_at, :datetime
  end
end
