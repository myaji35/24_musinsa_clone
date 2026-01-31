class Product < ApplicationRecord
  has_many :reviews, dependent: :destroy
  has_many :snap_products, dependent: :destroy
  has_many :snaps, through: :snap_products
  has_many :variants, dependent: :destroy
  has_many :orders
  has_many :campaigns # Epic 6.1

  # Active Storage 이미지 첨부 (Story 1.1)
  has_one_attached :image

  # Nested attributes for Variants (Story 1.3)
  accepts_nested_attributes_for :variants, allow_destroy: true, reject_if: :all_blank

  # AI 속성을 JSON으로 저장/파싱
  serialize :ai_attributes, coder: JSON
  serialize :badges, coder: JSON

  # 유효성 검증 (Story 1.1 Acceptance Criteria)
  validates :name, presence: true, length: { maximum: 200 }
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :brand, presence: true
  validates :category, presence: true
  validates :description, length: { maximum: 500 }, allow_blank: true

  # AI 속성 필터링 Scopes (Story 1.2)
  scope :by_mood, ->(mood) { where("ai_attributes LIKE ?", "%\"mood\":%\"#{mood}\"%") }
  scope :by_tpo, ->(tpo) { where("ai_attributes LIKE ?", "%\"tpo\":%\"#{tpo}\"%") }
  scope :by_fit_style, ->(fit_style) { where("ai_attributes LIKE ?", "%\"fit_style\":\"#{fit_style}\"%") }
  scope :by_material_feel, ->(material_feel) { where("ai_attributes LIKE ?", "%\"material_feel\":\"#{material_feel}\"%") }

  # 배지 관련 헬퍼 메서드
  def badge_list
    badges || []
  end

  def free_shipping?
    price >= 30000 # 3만원 이상 무료배송
  end

  def has_coupon?
    badge_list.include?("coupon")
  end

  def new_arrival?
    is_new || (created_at && created_at > 7.days.ago)
  end

  def restocked?
    restocked_at && restocked_at > 7.days.ago
  end

  # AI 속성 접근자 (안전하게 파싱)
  def parsed_ai_attributes
    return {} if ai_attributes.blank?

    if ai_attributes.is_a?(String)
      JSON.parse(ai_attributes) rescue {}
    else
      ai_attributes || {}
    end
  end

  def mood
    parsed_ai_attributes["mood"]
  end

  def tpo
    parsed_ai_attributes["tpo"]
  end

  def fit_style
    parsed_ai_attributes["fit_style"]
  end

  def material_feel
    parsed_ai_attributes["material_feel"]
  end
end
