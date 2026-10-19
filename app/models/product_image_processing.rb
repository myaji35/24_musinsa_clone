class ProductImageProcessing < ApplicationRecord
  self.table_name = "image_processings"

  KINDS = %w[cutout try_on].freeze
  STATUSES = %w[pending processing succeeded failed skipped].freeze
  IN_PROGRESS_STATUSES = %w[pending processing].freeze
  # 자체 호스팅 공급사는 과금이 없어 월 호출 상한 집계에서 뺀다.
  SELF_HOSTED_PREFIX = "self-hosted:".freeze

  belongs_to :product

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }

  scope :this_month, -> { where(created_at: Time.current.beginning_of_month...Time.current.next_month.beginning_of_month) }
  scope :external_calls, -> {
    where(status: %w[processing succeeded failed]).where.not(provider: [ nil, "" ])
      .where.not("provider LIKE ?", "#{SELF_HOSTED_PREFIX}%")
  }
  scope :cutouts, -> { where(kind: "cutout") }
  scope :in_progress, -> { where(status: IN_PROGRESS_STATUSES) }

  def self.monthly_limit
    limit = Integer(ENV["IMAGE_PROCESSING_MONTHLY_LIMIT"], 10)
    limit.negative? ? 0 : limit
  rescue ArgumentError, TypeError
    0
  end

  def self.limit_reached?
    external_calls.this_month.count >= monthly_limit
  end

  def in_progress?
    status.in?(IN_PROGRESS_STATUSES)
  end

  def mark_failed!(message)
    update!(status: "failed", error_message: message, finished_at: Time.current)
  end

  def mark_skipped!(message)
    update!(status: "skipped", error_message: message, finished_at: Time.current)
  end
end
