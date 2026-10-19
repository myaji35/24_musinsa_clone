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

  def self.for_intro
    axes = YAML.load_file(Rails.root.join("config/characters.yml")).map { |attributes| attributes.fetch("style_axis") }.uniq
    all.sort_by { |character| [ axes.index(character.style_axis) || axes.length, character.age_band || 0, character.handle ] }
  end

  scope :active, -> { where(status: "active") }
end
