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

  def recommended_products(limit: 8)
    analyses = ProductAnalysis.where(status: "done")
      .where(character_id: id).or(ProductAnalysis.where(status: "done", alt_character_id: id))
    Product.published.where(id: analyses.select(:product_id)).with_attached_image.includes(:reviews)
      .order(created_at: :desc, id: :desc).limit(limit)
  end

  def similar_characters(limit: 4)
    return self.class.none if style_axis.blank?

    self.class.where(style_axis: style_axis).where.not(id: id).order(:handle).limit(limit)
  end

  scope :active, -> { where(status: "active") }
end
