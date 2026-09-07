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

  before_validation :normalize_ai_data

  # 유효성 검증 (Story 1.1 Acceptance Criteria)
  validates :name, presence: true, length: { maximum: 200 }
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :brand, presence: true
  validates :category, presence: true
  validates :description, length: { maximum: 500 }, allow_blank: true
  validate :validate_image

  # AI 속성 필터링 Scopes (Story 1.2)
  scope :by_mood, ->(mood) { where("json_extract(ai_attributes, '$.mood') LIKE ? ESCAPE '\\'", "%#{sanitize_sql_like(mood.to_s.to_json)}%") }
  scope :by_tpo, ->(tpo) { where("json_extract(ai_attributes, '$.tpo') LIKE ? ESCAPE '\\'", "%#{sanitize_sql_like(tpo.to_s.to_json)}%") }
  scope :by_fit_style, ->(fit_style) { where("json_extract(ai_attributes, '$.fit_style') LIKE ? ESCAPE '\\'", sanitize_sql_like(fit_style.to_s)) }
  scope :by_material_feel, ->(material_feel) { where("json_extract(ai_attributes, '$.material_feel') LIKE ? ESCAPE '\\'", sanitize_sql_like(material_feel.to_s)) }

  # 배지 관련 헬퍼 메서드
  def badge_list
    value = parse_json_value(badges)
    value.is_a?(Array) ? value : []
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
    value = parse_json_value(ai_attributes)
    value.is_a?(Hash) ? value : {}
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
  private

  # 첨부 이미지 형식 및 크기 검증
  def validate_image
    return unless image.attached?

    unless image.content_type.in?(%w[image/png image/jpeg image/webp])
      errors.add(:image, "는 PNG, JPEG, WebP 형식만 업로드할 수 있습니다")
    end
    if image.byte_size > 10.megabytes
      errors.add(:image, "는 10MB 이하여야 합니다")
    end
  end

  # 기존 문자열 입력도 저장 시 Hash/Array로 통일
  def normalize_ai_data
    attributes = parsed_ai_attributes.stringify_keys
    %w[mood tpo].each do |key|
      attributes[key] = Array(attributes[key]).reject(&:blank?) if attributes.key?(key)
    end
    self.ai_attributes = attributes
    self.badges = badge_list
  end

  def parse_json_value(value)
    value.is_a?(String) ? JSON.parse(value) : value
  rescue JSON::ParserError
    nil
  end
end
