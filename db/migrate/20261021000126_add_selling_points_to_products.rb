class AddSellingPointsToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :selling_points, :text
  end
end
