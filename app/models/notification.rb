# Epic 5.1: 재고 부족 알림 모델
# Claude API로 생성된 메시지를 저장하고 발송 상태 관리
class Notification < ApplicationRecord
  belongs_to :variant

  # Validations
  validates :notification_type, presence: true, inclusion: { in: %w[low_stock restock_needed out_of_stock] }
  validates :status, inclusion: { in: %w[pending sent failed] }

  # Scopes
  scope :pending, -> { where(status: "pending") }
  scope :sent, -> { where(status: "sent") }
  scope :failed, -> { where(status: "failed") }
  scope :low_stock_alerts, -> { where(notification_type: "low_stock") }
  scope :restock_alerts, -> { where(notification_type: "restock_needed") }
  scope :recent, -> { order(created_at: :desc) }

  # Methods

  # 알림을 발송 완료로 표시
  def mark_as_sent!
    update(status: "sent", sent_at: Time.current)
  end

  # 알림 발송 실패로 표시
  def mark_as_failed!
    update(status: "failed")
  end

  # 중복 알림 방지: 같은 variant에 대해 24시간 이내에 발송된 알림이 있는지 확인
  def self.already_sent_recently?(variant_id, notification_type, hours = 24)
    where(variant_id: variant_id, notification_type: notification_type)
      .where("sent_at > ?", hours.hours.ago)
      .exists?
  end
end
