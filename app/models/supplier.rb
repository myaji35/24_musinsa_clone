# Epic 8.1: 거래처(공급처) 관리
# 발주를 넣을 도매상/공급업체 정보 관리
class Supplier < ApplicationRecord
  include AccountScoped

  has_many :ledger_entries, dependent: :restrict_with_error
  validates :kind, inclusion: { in: %w[purchase sales both], message: "구분이 올바르지 않습니다" }
  scope :purchase_side, -> { where(kind: %w[purchase both]) }
  scope :sales_side, -> { where(kind: %w[sales both]) }

  has_many :supplier_accounts, dependent: :destroy
  has_many :supplier_claims, dependent: :destroy
  has_many :products
  has_many :purchase_orders, dependent: :destroy

  # Validations
  validates :name, presence: { message: "거래처명을 입력해 주세요" }, uniqueness: { scope: :account_id, message: "같은 이름의 거래처가 이미 있습니다" }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "이메일 형식이 올바르지 않습니다" }, allow_blank: true
  validates :phone, presence: { message: "전화번호를 입력해 주세요" }

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
