class CreateLedger < ActiveRecord::Migration[8.1]
  def up
    add_reference :suppliers, :account, foreign_key: true
    execute "UPDATE suppliers SET account_id = (SELECT id FROM accounts WHERE slug = 'jieum')"
    change_column_null :suppliers, :account_id, false
    add_column :suppliers, :kind, :string, null: false, default: "purchase"
    add_column :suppliers, :business_number, :string
    remove_index :suppliers, :name
    add_index :suppliers, [ :account_id, :name ], unique: true

    create_table :ledger_entries do |t|
      t.references :account, null: false, foreign_key: true
      t.references :supplier, null: false, foreign_key: true
      t.string :entry_type, null: false
      t.date :occurred_on, null: false
      t.string :item_name
      t.integer :quantity
      t.string :unit
      t.decimal :unit_price, precision: 12, scale: 2
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.date :due_on
      t.text :memo
      t.references :source, polymorphic: true
      t.references :created_by_user, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :ledger_entries, [ :account_id, :supplier_id, :occurred_on ]
    add_index :ledger_entries, [ :source_type, :source_id, :entry_type ], unique: true, where: "source_id IS NOT NULL AND entry_type = 'purchase'", name: "index_ledger_purchase_source"
  end

  def down
    drop_table :ledger_entries
    remove_index :suppliers, [ :account_id, :name ]
    add_index :suppliers, :name, unique: true
    remove_column :suppliers, :business_number
    remove_column :suppliers, :kind
    remove_reference :suppliers, :account, foreign_key: true
  end
end
