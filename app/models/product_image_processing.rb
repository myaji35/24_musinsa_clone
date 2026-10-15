class ProductImageProcessing < ApplicationRecord
  self.table_name = "image_processings"

  KINDS = %w[cutout try_on].freeze
  STATUSES = %w[pending processing succeeded failed skipped].freeze

  belongs_to :product

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }

  scope :this_month, -> { where(created_at: Time.current.beginning_of_month...Time.current.next_month.beginning_of_month) }
  scope :external_calls, -> { where(status: %w[processing succeeded failed]).where.not(provider: [ nil, "" ]) }

  def self.monthly_limit
    limit = Integer(ENV["IMAGE_PROCESSING_MONTHLY_LIMIT"], 10)
    limit.negative? ? 0 : limit
  rescue ArgumentError, TypeError
    0
  end

  def self.limit_reached?
    external_calls.this_month.count >= monthly_limit
  end

  def mark_failed!(message)
    update!(status: "failed", error_message: message, finished_at: Time.current)
  end

  def mark_skipped!(message)
    update!(status: "skipped", error_message: message, finished_at: Time.current)
  end
end
