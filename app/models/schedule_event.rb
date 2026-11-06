class ScheduleEvent < ApplicationRecord
  include AccountScoped

  KINDS = { "delivery" => "납품·입고", "payment" => "수금·지급", "meeting" => "약속", "issue" => "이슈", "other" => "기타" }.freeze
  STATUSES = { "open" => "미완료", "done" => "완료", "cancelled" => "취소" }.freeze

  belongs_to :supplier, optional: true
  belongs_to :source, polymorphic: true, optional: true
  belongs_to :created_by_user, class_name: "User", optional: true
  validates :title, presence: { message: "제목을 입력해 주세요" }
  validates :starts_on, presence: { message: "일자를 입력해 주세요" }
  validates :kind, inclusion: { in: KINDS.keys, message: "일정 종류가 올바르지 않습니다" }
  validates :status, inclusion: { in: STATUSES.keys, message: "일정 상태가 올바르지 않습니다" }
  validate :supplier_account_matches

  private

  def supplier_account_matches
    errors.add(:supplier, "거래처와 계정이 일치하지 않습니다") if supplier && supplier.account_id != account_id
  end
end
