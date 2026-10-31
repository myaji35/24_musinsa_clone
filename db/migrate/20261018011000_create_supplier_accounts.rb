class CreateSupplierAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :supplier_accounts do |t|
      t.references :supplier, null: false, foreign_key: true
      t.string :email, null: false
      t.string :name
      t.string :password_digest, null: false
      t.datetime :last_sign_in_at
      t.boolean :active, default: true, null: false
      t.timestamps
    end
    add_index :supplier_accounts, :email, unique: true
  end
end
