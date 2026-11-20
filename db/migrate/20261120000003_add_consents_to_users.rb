class AddConsentsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :terms_agreed_at, :datetime, null: true
    add_column :users, :privacy_agreed_at, :datetime, null: true
    add_column :users, :age_confirmed_at, :datetime, null: true
  end
end
