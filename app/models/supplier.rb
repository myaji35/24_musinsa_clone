# Epic 8.1: 거래처(공급처) 관리
# 발주를 넣을 도매상/공급업체 정보 관리
class Supplier < ApplicationRecord
  has_many :purchase_orders, dependent: :destroy

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :phone, presence: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :recent, -> { order(created_at: :desc) }

  # Methods
  def display_name
    contact_person.present? ? "#{name} (#{contact_person})" : name
  end

  def active?
    active.nil? ? true : active # 기본값 true
  end
end
