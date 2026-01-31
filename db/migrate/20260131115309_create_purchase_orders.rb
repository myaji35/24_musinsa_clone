class CreatePurchaseOrders < ActiveRecord::Migration[7.2]
  def change
    create_table :purchase_orders do |t|
      t.references :supplier, null: false, foreign_key: true
      t.string :order_number, null: false # PO-YYYYMMDD-HEX4
      t.string :status, default: "draft" # draft, submitted, confirmed, received, cancelled
      t.date :expected_delivery_date
      t.decimal :total_amount, precision: 10, scale: 2, default: 0
      t.text :notes
      t.string :confirmation_token # 거래처 확인용 토큰
      t.datetime :confirmed_at # 거래처가 확정한 시각
      t.datetime :received_at # 실제 입고 완료 시각

      t.timestamps
    end

    add_index :purchase_orders, :order_number, unique: true
    add_index :purchase_orders, :status
    add_index :purchase_orders, :confirmation_token
  end
end
