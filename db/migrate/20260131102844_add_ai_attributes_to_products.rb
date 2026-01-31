class AddAiAttributesToProducts < ActiveRecord::Migration[7.2]
  def change
    add_column :products, :ai_attributes, :text
    add_column :products, :badges, :text
    add_column :products, :is_new, :boolean, default: false
    add_column :products, :restocked_at, :datetime
  end
end
