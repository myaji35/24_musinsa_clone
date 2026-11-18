class AddPartialReceivingToPurchaseOrders < ActiveRecord::Migration[8.1]
  def up
    add_column :purchase_order_items, :received_quantity, :integer, default: 0, null: false
    execute "UPDATE purchase_order_items SET received_quantity = quantity WHERE purchase_order_id IN (SELECT id FROM purchase_orders WHERE status = 'received')"
    remove_index :ledger_entries, name: :index_ledger_purchase_source
    add_index :ledger_entries, [ :source_type, :source_id, :entry_type ], unique: true,
      where: "source_id IS NOT NULL AND entry_type = 'purchase' AND source_type != 'PurchaseOrder'", name: :index_ledger_purchase_source
  end

  def down
    remove_index :ledger_entries, name: :index_ledger_purchase_source
    add_index :ledger_entries, [ :source_type, :source_id, :entry_type ], unique: true,
      where: "source_id IS NOT NULL AND entry_type = 'purchase'", name: :index_ledger_purchase_source
    remove_column :purchase_order_items, :received_quantity
  end
end
