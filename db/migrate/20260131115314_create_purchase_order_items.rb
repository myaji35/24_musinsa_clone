class CreatePurchaseOrderItems < ActiveRecord::Migration[7.2]
  def change
    create_table :purchase_order_items do |t|
      t.references :purchase_order, null: false, foreign_key: true
      t.references :variant, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.decimal :unit_price, precision: 10, scale: 2, null: false # 사입가
      t.decimal :subtotal, precision: 10, scale: 2, null: false # quantity * unit_price

      t.timestamps
    end

    add_index :purchase_order_items, [:purchase_order_id, :variant_id], unique: true, name: 'index_po_items_on_po_and_variant'
  end
end
