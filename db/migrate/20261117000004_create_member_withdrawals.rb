class CreateMemberWithdrawals < ActiveRecord::Migration[8.1]
  def change
    create_table :member_withdrawals do |t|
      t.datetime :withdrawn_at, null: false
      t.integer :orders_count, default: 0, null: false
      t.string :reason, limit: 30

      t.timestamps
    end
  end
end
