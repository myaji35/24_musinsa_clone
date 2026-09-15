class Order < ApplicationRecord
  # Relations
  belongs_to :anony_customer
  belongs_to :product
  belongs_to :variant

  # Validations
  validates :quantity, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: %w[pending paid shipped delivered cancelled] }

  # Callbacks
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
    update(status: "delivered")
  end

  private

  def generate_order_number
    self.order_number ||= "ORD-#{Date.today.strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}"
  end

  # Epic 4.2: 주문 생성 시 백그라운드로 취향 태그 학습
  def enqueue_preference_update_job
    UpdatePreferenceTagsJob.perform_later(id)
  end
end
