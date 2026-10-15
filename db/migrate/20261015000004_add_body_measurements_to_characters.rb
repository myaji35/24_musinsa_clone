class AddBodyMeasurementsToCharacters < ActiveRecord::Migration[7.2]
  def change
    add_column :characters, :height_cm, :integer
    add_column :characters, :top_size, :string
    add_column :characters, :bottom_size, :string
    add_column :characters, :shoe_mm, :integer
    add_column :characters, :body_type, :string
  end
end
