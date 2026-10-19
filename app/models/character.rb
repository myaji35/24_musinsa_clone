class Character < ApplicationRecord
  has_many :worn_products, class_name: "Product", foreign_key: :worn_character_id, dependent: :nullify
  has_many :product_analyses
  validates :name, :handle, presence: true
  validates :handle, uniqueness: true
  validates :age, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :age_band, inclusion: { in: [ 20, 30, 40, 50 ] }, allow_nil: true
  validates :height_cm, numericality: { only_integer: true, in: 140..190 }, allow_nil: true
  validates :shoe_mm, numericality: { only_integer: true, in: 210..280 }, allow_nil: true
  validates :status, inclusion: { in: %w[active planned] }

  scope :active, -> { where(status: "active") }
end
