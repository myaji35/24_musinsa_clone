class CreateOrders < ActiveRecord::Migration[7.2]
  def change
    create_table :orders do |t|
      t.references :anony_customer, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :variant, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.decimal :total_price, precision: 10, scale: 2, null: false
      t.string :status, default: "pending" # pending, paid, shipped, delivered, cancelled
      t.string :order_number, null: false # 주문번호: ORD-20260131-XXXX

      t.timestamps
    end

    add_index :orders, :order_number, unique: true
    add_index :orders, :status
    add_index :orders, :created_at
  end
end
