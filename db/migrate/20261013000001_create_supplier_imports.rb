class CreateSupplierImports < ActiveRecord::Migration[7.2]
  def change
    create_table :supplier_imports do |t|
      t.integer :supplier_id
      t.string :status, default: "pending"
      t.integer :total_rows, default: 0
      t.integer :imported_rows, default: 0
      t.integer :updated_rows, default: 0
      t.integer :failed_rows, default: 0
      t.text :row_results
      t.text :error_message
      t.timestamps
    end
    add_index :supplier_imports, :supplier_id
  end
end
