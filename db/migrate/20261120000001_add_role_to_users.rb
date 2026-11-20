class AddRoleToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :role, :integer, null: false, default: 0
    add_index :users, :role

    # 기존 관리자에게 관리자 역할을 부여한다.
    execute <<~SQL
      UPDATE users
      SET role = 2
      WHERE account_id IS NULL
         OR account_id IN (SELECT id FROM accounts WHERE slug = 'jieum')
    SQL
  end

  def down
    remove_column :users, :role
  end
end
