class CreateStockHolds < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_holds do |t|
      t.references :variant, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.string :token, null: false
      t.datetime :expires_at, null: false
      t.string :status, null: false, default: "held"
      t.references :order, foreign_key: true
      t.string :source
      t.timestamps
    end
    add_index :stock_holds, :token, unique: true
    add_index :stock_holds, :expires_at
  end
end
