class Order < ApplicationRecord
  # 배송지 파기 시계가 도는 종결 상태 (ISS-058 C안)
  FINISHED_STATUSES = %w[delivered cancelled].freeze

  # Relations
  belongs_to :anony_customer
  belongs_to :product
  belongs_to :variant
  belongs_to :shipping_address, optional: true

  # Validations
  validates :quantity, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: %w[pending paid shipped delivered cancelled] }

  # Callbacks
  before_save :record_delivery_time
  after_save :schedule_shipping_address_purge, if: -> { saved_change_to_status? && status.in?(FINISHED_STATUSES) }
  before_create :generate_order_number
  after_create :enqueue_preference_update_job # Epic 4.2: 주문 생성 시 자동 취향 학습

  # Scopes
  scope :pending, -> { where(status: "pending") }
  scope :paid, -> { where(status: "paid") }
  scope :shipped, -> { where(status: "shipped") }
  scope :delivered, -> { where(status: "delivered") }
  scope :cancelled, -> { where(status: "cancelled") }
  scope :recent, -> { order(created_at: :desc) }

  # Methods

  # 주문 완료 처리
  def complete!
    update!(status: "delivered")
  end

  private

  def record_delivery_time
    self.delivered_at = Time.current if will_save_change_to_status? && status == "delivered"
  end

  # 같은 배송지를 쓰는 주문이 모두 종결(배송완료·취소)된 뒤에만 파기 예정일을 잡는다
  def schedule_shipping_address_purge
    return unless shipping_address
    return if shipping_address.orders.where.not(status: FINISHED_STATUSES).exists?

    shipping_address.schedule_purge!(from: delivered_at || Time.current)
  end

  def generate_order_number
    self.order_number ||= "ORD-#{Date.today.strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}"
  end

  # Epic 4.2: 주문 생성 시 백그라운드로 취향 태그 학습
  def enqueue_preference_update_job
    UpdatePreferenceTagsJob.perform_later(id)
  end
end
