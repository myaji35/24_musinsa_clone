# Epic 8.2: 발주서 관리
# 거래처에게 발주하는 주문서
class PurchaseOrder < ApplicationRecord
  belongs_to :supplier
  has_many :purchase_order_items, dependent: :destroy
  has_many :variants, through: :purchase_order_items

  # Nested attributes for items
  accepts_nested_attributes_for :purchase_order_items, allow_destroy: true, reject_if: :all_blank

  # Validations
  validates :order_number, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[draft submitted confirmed received cancelled] }

  # Callbacks
  before_validation :generate_order_number, on: :create
  before_validation :generate_confirmation_token, on: :create
  before_save :calculate_total_amount

  # Scopes
  scope :draft, -> { where(status: "draft") }
  scope :submitted, -> { where(status: "submitted") }
  scope :confirmed, -> { where(status: "confirmed") }
  scope :received, -> { where(status: "received") }
  scope :pending, -> { where(status: [ "submitted", "confirmed" ]) }
  scope :recent, -> { order(created_at: :desc) }

  # Methods

  # 발주서 제출 (거래처에게 발송)
  # 이메일 발송은 PurchaseOrdersController#submit에서 처리
  def submit!
    return false unless status == "draft"

    update(status: "submitted")
  end

  # 거래처가 확정
  def confirm!
    update(
      status: "confirmed",
      confirmed_at: Time.current
    )
  end

  # 실제 입고 처리
  def receive!
    return false unless status == "confirmed"

    ActiveRecord::Base.transaction do
      # 1. 각 아이템별로 StockLog 생성 및 재고 증가
      purchase_order_items.each do |item|
        StockLog.create!(
          variant: item.variant,
          log_type: "in",
          quantity: item.quantity,
          supplier: supplier.name,
          unit_cost: item.unit_price,
          note: "발주서 입고: #{order_number}"
        )
      end

      # 2. 발주서 상태 변경
      update!(
        status: "received",
        received_at: Time.current
      )
    end

    true
  rescue => e
    Rails.logger.error "PO 입고 실패: #{e.message}"
    false
  end

  # 확인 URL 생성
  def confirmation_url
    Rails.application.routes.url_helpers.confirm_purchase_order_url(
      token: confirmation_token,
      host: ENV["APP_HOST"] || "localhost:3000"
    )
  end

  private

  def generate_order_number
    self.order_number ||= "PO-#{Date.today.strftime('%Y%m%d')}-#{SecureRandom.hex(2).upcase}"
  end

  def generate_confirmation_token
    self.confirmation_token ||= SecureRandom.urlsafe_base64(32)
  end

  def calculate_total_amount
    self.total_amount = purchase_order_items.map { |item| item.quantity * item.unit_price }.sum
  end
end
