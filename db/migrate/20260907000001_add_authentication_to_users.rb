class AddAuthenticationToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :password_digest, :string
    add_index :users, :email, unique: true
  end
end
