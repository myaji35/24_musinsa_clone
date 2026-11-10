class StockLog < ApplicationRecord
  attr_accessor :skip_variant_stock_update

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
  after_create_commit :enqueue_shopify_sync

  # 입고인지 확인
  def stock_in?
    log_type == "in"
  end

  # 출고인지 확인
  def stock_out?
    log_type == "out"
  end

  private

  def enqueue_shopify_sync
    return unless ENV["SHOPIFY_SYNC_ENABLED"] == "1"
    return if Shopify::Listings.for_variant(variant).empty?

    ShopifyInventorySyncJob.perform_later(variant_id)
  end

  def update_variant_stock
    return if skip_variant_stock_update
    return unless variant

    if stock_in?
      variant.increment!(:stock, quantity)
    elsif stock_out?
      variant.decrement!(:stock, quantity)
    end
  end
end
