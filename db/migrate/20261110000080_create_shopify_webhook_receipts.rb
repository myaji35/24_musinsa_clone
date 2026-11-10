class CreateShopifyWebhookReceipts < ActiveRecord::Migration[8.1]
  def change
    create_table :shopify_webhook_receipts do |t|
      t.string :webhook_id, null: false
      t.string :topic
      t.string :shopify_order_id
      t.datetime :processed_at
      t.json :issues, default: [], null: false
      t.timestamps
    end
    add_index :shopify_webhook_receipts, :webhook_id, unique: true
  end
end
