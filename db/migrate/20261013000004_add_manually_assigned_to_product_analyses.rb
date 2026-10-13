class AddManuallyAssignedToProductAnalyses < ActiveRecord::Migration[7.2]
  def change
    add_column :product_analyses, :manually_assigned, :boolean, default: false, null: false
  end
end
