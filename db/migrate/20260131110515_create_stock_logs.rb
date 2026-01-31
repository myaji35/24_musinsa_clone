class CreateStockLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :stock_logs do |t|
      t.references :variant, null: false, foreign_key: true
      t.string :log_type, null: false # 'in' 또는 'out'
      t.integer :quantity, null: false
      t.string :supplier # 입고 시 사입처
      t.decimal :unit_cost, precision: 10, scale: 2 # 단가
      t.integer :order_id # 출고 시 주문 ID
      t.text :note # 메모

      t.timestamps
    end

    add_index :stock_logs, :log_type
    add_index :stock_logs, :created_at
  end
end
