class StockLog < ApplicationRecord
  belongs_to :variant

  # 유효성 검증
  validates :log_type, presence: true, inclusion: { in: %w[in out] }
  validates :quantity, presence: true, numericality: { greater_than: 0 }

  # Scopes
  scope :stock_in, -> { where(log_type: "in") }
  scope :stock_out, -> { where(log_type: "out") }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }

  # Callbacks
  after_create :update_variant_stock

  # 입고인지 확인
  def stock_in?
    log_type == "in"
  end

  # 출고인지 확인
  def stock_out?
    log_type == "out"
  end

  private

  def update_variant_stock
    return unless variant

    if stock_in?
      variant.increment!(:stock, quantity)
    elsif stock_out?
      variant.decrement!(:stock, quantity)
    end
  end
end
