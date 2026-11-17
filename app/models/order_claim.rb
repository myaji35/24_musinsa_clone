class OrderClaim < ApplicationRecord
  # 소비자 불만·분쟁 기록 보관 기간
  RETENTION_YEARS = 3
  KINDS = { "cancel" => "취소", "return" => "반품", "exchange" => "교환" }.freeze
  STATUSES = { "requested" => "접수", "approved" => "승인", "rejected" => "거절", "completed" => "완료" }.freeze
  REASONS = { "changed_mind" => "단순 변심", "size" => "사이즈 불만", "defect" => "상품 불량",
              "wrong_item" => "오배송", "late" => "배송 지연", "other" => "기타" }.freeze

  belongs_to :order
  belongs_to :user, optional: true
  belongs_to :processed_by, class_name: "User", foreign_key: :processed_by_user_id, optional: true

  validates :kind, presence: true, inclusion: { in: KINDS.keys }
  validates :status, presence: true, inclusion: { in: STATUSES.keys }
  validates :reason_code, presence: true, inclusion: { in: REASONS.keys }
  validates :requester, presence: true, inclusion: { in: %w[member guest] }
  validates :detail, length: { maximum: 500 }
  validate :no_other_active_claim

  def kind_label
    KINDS.fetch(kind, kind)
  end

  def status_label
    STATUSES.fetch(status, status)
  end

  def reason_label
    REASONS.fetch(reason_code, reason_code)
  end

  private

  def no_other_active_claim
    return unless order
    if order.order_claims.where(status: %w[requested approved]).where.not(id: id).exists?
      errors.add(:base, "이미 처리 중인 요청이 있습니다.")
    end
  end
end
