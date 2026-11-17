class WechatMessage < ApplicationRecord
  include AccountScoped
  belongs_to :wechat_contact
  belongs_to :purchase_order, optional: true
  belongs_to :sent_by, class_name: "User", optional: true
  belongs_to :processed_by, class_name: "User", optional: true
  validates :direction, inclusion: { in: %w[in out] }
  validates :status, inclusion: { in: %w[received sent failed disabled window_closed pending_manual sent_manual received_manual awaiting_approval queued_mac sent_mac received_mac] }
  validates :msg_type, presence: true
  validates :content, presence: true, length: { maximum: 2000 }, if: -> { direction == "out" || status.to_s.end_with?("_manual", "_mac") }
  validate do
    errors.add(:wechat_contact, "계정이 다릅니다") if wechat_contact && wechat_contact.account_id != account_id
    errors.add(:purchase_order, "계정이 다릅니다") if purchase_order && purchase_order.supplier.account_id != account_id
    errors.add(:processed_by, "계정이 다릅니다") if processed_by&.account_id && processed_by.account_id != account_id
    errors.add(:sent_by, "계정이 다릅니다") if sent_by&.account_id && sent_by.account_id != account_id
  end
end
