class LedgerEntry < ApplicationRecord
  include AccountScoped

  TYPES = { "sale" => "매출", "purchase" => "매입", "receipt" => "수금", "payment" => "지급", "adjustment" => "조정" }.freeze

  belongs_to :supplier
  belongs_to :source, polymorphic: true, optional: true
  belongs_to :created_by_user, class_name: "User", optional: true
  before_validation :default_amount
  validates :entry_type, inclusion: { in: TYPES.keys, message: "거래 유형이 올바르지 않습니다" }
  validates :occurred_on, presence: { message: "일자를 입력해 주세요" }
  validates :amount, presence: { message: "금액을 입력해 주세요(수량과 단가를 넣으면 자동 계산)" }
  validates :amount, numericality: { greater_than: 0, message: ->(_record, data) { data[:count] == 0 ? "금액은 0보다 커야 합니다" : "금액은 숫자여야 합니다" } }, allow_blank: true, unless: -> { entry_type == "adjustment" }
  validates :amount, numericality: { message: "금액은 숫자여야 합니다" }, allow_blank: true, if: -> { entry_type == "adjustment" }
  validate :supplier_account_matches
  validate :no_future_settlement

  def receivable_change
    case entry_type
    when "sale", "adjustment" then amount
    when "receipt" then -amount
    else 0.to_d
    end
  end

  def payable_change
    case entry_type
    when "purchase" then amount
    when "payment" then -amount
    else 0.to_d
    end
  end

  private

  def no_future_settlement
    if entry_type.in?(%w[receipt payment]) && occurred_on && occurred_on > Date.current
      errors.add(:base, "미래 날짜의 수금·지급은 기록할 수 없습니다 — 일정으로 반영해 주세요")
    end
  end

  def default_amount
    self.amount = quantity * unit_price if amount.nil? && entry_type.in?(%w[sale purchase]) && quantity && unit_price
  end

  def supplier_account_matches
    errors.add(:supplier, "거래처와 계정이 일치하지 않습니다") if supplier && supplier.account_id != account_id
  end
end
