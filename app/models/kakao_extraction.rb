class KakaoExtraction < ApplicationRecord
  include AccountScoped

  KIND_LABELS = { "schedule" => "일정", "order" => "주문·발주", "delivery" => "납품·입고", "payment" => "입금·지급", "issue" => "이슈" }.freeze
  PROGRESS_LABELS = { "planned" => "예정", "done" => "완료", "unknown" => "불명" }.freeze
  KINDS = %w[schedule order delivery payment issue].freeze
  belongs_to :kakao_room
  belongs_to :supplier, optional: true
  belongs_to :applied, polymorphic: true, optional: true
  belongs_to :reviewed_by_user, class_name: "User", optional: true
  has_many :kakao_extraction_messages, dependent: :destroy
  has_many :kakao_messages, through: :kakao_extraction_messages
  validates :summary, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :progress, inclusion: { in: PROGRESS_LABELS.keys }
  validates :status, inclusion: { in: %w[pending approved rejected superseded] }
  validates :applied_type, inclusion: { in: %w[ScheduleEvent LedgerEntry] }, allow_nil: true
  validate :matching_accounts

  def self.dangerous_attribute_method?(name)
    return false if name == "model_name"

    super
  end

  # Active Record reserves model_name; keep the requested database field with explicit accessors.
  def model_name
    self[:model_name]
  end

  def model_name=(value)
    self[:model_name] = value
  end

  def default_target
    return "schedule" if progress == "planned"

    case kind
    when "payment"
      return "schedule" unless progress == "done" && (date.nil? || date <= Date.current)

      supplier&.kind == "sales" ? "receipt" : "payment"
    when "order" then supplier&.kind == "sales" ? "sale" : "purchase"
    else "schedule"
    end
  end

  private

  def matching_accounts
    [ kakao_room, supplier, applied, reviewed_by_user ].compact.each do |record|
      errors.add(:account, "관련 데이터의 계정이 일치하지 않습니다") if record.account_id != account_id
    end
  end
end
