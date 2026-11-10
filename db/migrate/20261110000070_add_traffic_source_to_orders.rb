class AddTrafficSourceToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :source_platform, :string
    add_column :orders, :source_campaign, :string
    add_column :orders, :source_video_id, :string
    add_column :orders, :source_link_code, :string
    add_column :orders, :source_character_id, :integer
    add_column :orders, :source_landed_at, :datetime
    add_index :orders, :source_platform
    add_index :orders, :source_character_id
    add_index :orders, :source_link_code
  end
end
