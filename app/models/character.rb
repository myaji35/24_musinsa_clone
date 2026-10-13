class Character < ApplicationRecord
  has_many :product_analyses
  validates :name, :handle, presence: true
  validates :handle, uniqueness: true
  validates :age, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :age_band, inclusion: { in: [ 20, 30, 40, 50 ] }, allow_nil: true
  validates :status, inclusion: { in: %w[active planned] }

  scope :active, -> { where(status: "active") }
end
