class CreateCampaignDeliveries < ActiveRecord::Migration[7.2]
  def change
    add_column :campaigns, :failure_reason, :text

    create_table :campaign_deliveries do |t|
      t.references :campaign, null: false, foreign_key: true
      t.references :anony_customer, null: false, foreign_key: true
      t.string :status, default: "pending", null: false
      t.string :channel, default: "internal", null: false
      t.text :message
      t.text :failure_reason
      t.datetime :sent_at
      t.timestamps
    end

    add_index :campaign_deliveries, [ :campaign_id, :anony_customer_id ], unique: true
    add_index :campaign_deliveries, :status
  end
end
