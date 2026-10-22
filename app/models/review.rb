class Review < ApplicationRecord
  belongs_to :user
  belongs_to :product

  validates :rating, presence: true, numericality: { only_integer: true, in: 1..5 }
  validates :content, presence: true, length: { maximum: 1000 }

  # 착용감: 작다 · 딱맞다 · 크다
  FITS = { "small" => "작다", "just" => "딱맞다", "large" => "크다" }.freeze
  validates :fit, inclusion: { in: FITS.keys }, allow_blank: true

  def fit_label
    FITS[fit]
  end
end
