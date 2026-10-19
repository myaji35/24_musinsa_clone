class CampaignDelivery < ApplicationRecord
  belongs_to :campaign
  belongs_to :anony_customer

  validates :status, inclusion: { in: %w[pending sent failed skipped] }
  validates :channel, presence: true
  validates :anony_customer_id, uniqueness: { scope: :campaign_id }
end
