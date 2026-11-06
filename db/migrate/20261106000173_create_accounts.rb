class CreateAccounts < ActiveRecord::Migration[8.1]
  def up
    create_table :accounts do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps
    end
    add_index :accounts, :slug, unique: true
    add_reference :users, :account, null: true, foreign_key: true
    execute "INSERT INTO accounts (id, name, slug, created_at, updated_at) VALUES (1, 'JIEUM', 'jieum', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
    execute "UPDATE users SET account_id = 1"
  end

  def down
    remove_reference :users, :account, foreign_key: true
    drop_table :accounts
  end
end
