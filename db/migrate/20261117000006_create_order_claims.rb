class CreateOrderClaims < ActiveRecord::Migration[8.1]
  def change
    create_table :order_claims do |t|
      t.references :order, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: { on_delete: :nullify }
      t.string :kind, null: false
      t.string :status, null: false, default: "requested"
      t.string :reason_code, null: false
      t.text :detail
      t.string :requester, null: false
      t.integer :processed_by_user_id
      t.datetime :processed_at
      t.text :admin_note
      t.datetime :refunded_at
      t.timestamps
    end
    add_foreign_key :order_claims, :users, column: :processed_by_user_id, on_delete: :nullify
    add_index :order_claims, [ :order_id, :status ]
  end
end
