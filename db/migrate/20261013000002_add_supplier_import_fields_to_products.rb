class AddSupplierImportFieldsToProducts < ActiveRecord::Migration[7.2]
  def change
    add_column :products, :supply_price, :decimal, precision: 10, scale: 2
    add_column :products, :supplier_import_id, :integer
    add_column :products, :supplier_product_code, :string
    add_column :products, :supplier_id, :integer
    add_index :products, :supplier_import_id
    add_index :products, :supplier_id
    add_index :products, [ :supplier_id, :supplier_product_code ]
  end
end
