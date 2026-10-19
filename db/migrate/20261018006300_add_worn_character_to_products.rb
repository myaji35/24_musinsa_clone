class AddWornCharacterToProducts < ActiveRecord::Migration[8.1]
  def change
    add_reference :products, :worn_character, foreign_key: { to_table: :characters }, null: true
    add_column :products, :worn_size, :string
  end
end
