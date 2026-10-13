class ProductAnalysis < ApplicationRecord
  belongs_to :product
  belongs_to :character, optional: true
  belongs_to :alt_character, class_name: "Character", optional: true

  validates :status, inclusion: { in: %w[pending running done failed] }
  validates :target_units_override, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  def effective_target_units
    target_units_override || target_units
  end
end
