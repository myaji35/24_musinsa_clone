class ShopifyWebhookReceipt < ApplicationRecord
  validates :webhook_id, presence: true, uniqueness: true
end
