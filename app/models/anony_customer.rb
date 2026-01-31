class AnonyCustomer < ApplicationRecord
  # Relations
  has_many :orders

  # JSON serialization for preference tags
  serialize :preference_tags, coder: JSON

  # Validations
  validates :uuid, presence: true, uniqueness: true
  validates :zip_prefix, length: { is: 3 }, allow_blank: true
  validates :phone_suffix, length: { is: 4 }, allow_blank: true

  # Callbacks
  before_validation :generate_uuid, on: :create

  # Methods

  # 상위 N개 취향 태그 반환
  def top_preferences(limit = 3)
    return [] if preference_tags.blank?

    preference_tags
      .sort_by { |_tag, count| -count }
      .first(limit)
      .to_h
  end

  # 중복 방지를 위한 찾기/생성
  def self.find_or_create_by_identifier(phone_suffix, birth_year)
    customer = find_by(phone_suffix: phone_suffix, birth_year: birth_year)
    return customer if customer.present?

    create(phone_suffix: phone_suffix, birth_year: birth_year)
  end

  # 취향 태그 누적
  def add_preference(tag, count = 1)
    self.preference_tags ||= {}
    self.preference_tags[tag] ||= 0
    self.preference_tags[tag] += count
    save
  end

  private

  def generate_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
