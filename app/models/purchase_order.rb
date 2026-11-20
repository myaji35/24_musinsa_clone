# Epic 8.2: 발주서 관리
# 거래처에게 발주하는 주문서
class PurchaseOrder < ApplicationRecord
  STATUS_LABELS = {
    "draft" => "작성 중",
    "submitted" => "발주 요청",
    "confirmed" => "거래처 확인",
    "received" => "입고 완료",
    "cancelled" => "취소"
  }.freeze

  belongs_to :supplier
  has_many :wechat_messages, dependent: :nullify
  has_many :purchase_order_items, dependent: :destroy
  has_many :variants, through: :purchase_order_items

  # Nested attributes for items
  accepts_nested_attributes_for :purchase_order_items, allow_destroy: true, reject_if: :all_blank

  # Validations
  validates :order_number, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[draft submitted confirmed partially_received received cancelled] }

  # Callbacks
  before_validation :generate_order_number, on: :create
  before_validation :generate_confirmation_token, on: :create
  before_save :calculate_total_amount

  # Scopes
  scope :draft, -> { where(status: "draft") }
  scope :submitted, -> { where(status: "submitted") }
  scope :confirmed, -> { where(status: "confirmed") }
  scope :received, -> { where(status: "received") }
  scope :pending, -> { where(status: [ "submitted", "confirmed", "partially_received" ]) }
  scope :recent, -> { order(created_at: :desc) }

  # Methods
  def status_label
    STATUS_LABELS.fetch(status, status)
  end

  # 발주서 제출 (거래처에게 발송)
  # 이메일 발송은 PurchaseOrdersController#submit에서 처리
  def submit!
    return false unless status == "draft"

    update(status: "submitted", confirmation_token_expires_at: 7.days.from_now)
  end

  # 거래처가 확정
  def confirm!
    return false unless status == "submitted"
    return false if confirmation_token_used_at.present?
    return false if confirmation_token_expires_at.present? && confirmation_token_expires_at.past?

    update(
      status: "confirmed",
      confirmed_at: Time.current,
      confirmation_token_used_at: Time.current
    )
  end

  def confirm_by_supplier!
    with_lock do
      return false unless status == "submitted"

      update!(status: "confirmed", confirmed_at: Time.current)
    end
  end

  # 실제 입고 처리
  def receive!(quantities = nil)
    with_lock do
      return false unless status.in?(%w[confirmed partially_received])

      items = purchase_order_items.to_a
      supplied = quantities&.to_h&.stringify_keys
      return false if supplied && (supplied.keys - items.map { |item| item.id.to_s }).any?

      amounts = items.to_h do |item|
        raw = supplied ? supplied.fetch(item.id.to_s, 0) : item.quantity - item.received_quantity
        quantity = Integer(raw, exception: false)
        return false unless quantity && quantity.between?(0, item.quantity - item.received_quantity)
        [ item, quantity ]
      end
      return false if amounts.values.sum.zero?

      amounts.each do |item, quantity|
        next if quantity.zero?
        StockLog.create!(variant: item.variant, log_type: "in", quantity: quantity,
          supplier: supplier.name, unit_cost: item.unit_price, note: "발주서 입고: #{order_number}")
        item.update!(received_quantity: item.received_quantity + quantity)
      end
      sequence = LedgerEntry.where(source: self, entry_type: "purchase").count + 1
      LedgerEntry.create!(source: self, entry_type: "purchase", account: supplier.account,
        supplier: supplier, occurred_on: Date.current, item_name: "발주 입고 #{order_number} (#{sequence}차)",
        amount: amounts.sum { |item, quantity| quantity * item.unit_price })
      complete = items.all? { |item| item.received_quantity == item.quantity }
      update!(status: complete ? "received" : "partially_received", received_at: complete ? Time.current : nil)
    end
    true
  rescue StandardError => e
    Rails.logger.error "PO 입고 실패: #{e.message}"
    false
  end

  # 확인 URL 생성
  def confirmation_url
    Rails.application.routes.url_helpers.confirm_purchase_order_url(
      token: confirmation_token,
      **(ENV["APP_HOST"].present? ? { host: ENV["APP_HOST"], protocol: Rails.application.config.action_mailer.default_url_options[:protocol] } : Rails.application.config.action_mailer.default_url_options.symbolize_keys)
    )
  end

  private

  def generate_order_number
    self.order_number ||= "PO-#{Date.current.strftime('%Y%m%d')}-#{SecureRandom.hex(2).upcase}"
  end

  def generate_confirmation_token
    self.confirmation_token ||= SecureRandom.urlsafe_base64(32)
  end

  def calculate_total_amount
    self.total_amount = purchase_order_items.map { |item| item.quantity * item.unit_price }.sum
  end
end
