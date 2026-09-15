class Review < ApplicationRecord
  belongs_to :user
  belongs_to :product

  validates :rating, presence: true, numericality: { only_integer: true, in: 1..5 }
  validates :content, presence: true, length: { maximum: 1000 }
end
