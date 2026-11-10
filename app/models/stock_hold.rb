class StockHold < ApplicationRecord
  belongs_to :variant
  belongs_to :order, optional: true

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :status, inclusion: { in: %w[held converted released] }

  scope :expired, -> { where(status: "held").where("expires_at <= ?", Time.current) }
end
