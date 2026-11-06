class AddSpecToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :spec, :text
  end
end
