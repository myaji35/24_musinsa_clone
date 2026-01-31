class CreateVariants < ActiveRecord::Migration[7.2]
  def change
    create_table :variants do |t|
      t.references :product, null: false, foreign_key: true
      t.string :sku_code
      t.string :color
      t.string :size
      t.string :barcode
      t.integer :stock
      t.integer :min_stock

      t.timestamps
    end
  end
end
