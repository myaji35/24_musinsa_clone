class WechatContact < ApplicationRecord
  include AccountScoped
  belongs_to :supplier, optional: true
  has_many :wechat_messages, dependent: :destroy
  validates :open_id, presence: true, if: -> { account&.wechat_channel_mode == "official" }
  validates :wechat_display_name, presence: true, if: -> { open_id.blank? }
  validates :wechat_display_name, uniqueness: { scope: :account_id }, allow_nil: true
  validate do
    errors.add(:supplier, "계정이 다릅니다") if supplier && supplier.account_id != account_id
  end

  def window_open?
    subscribed? && last_inbound_at.present? && last_inbound_at > 48.hours.ago
  end

  def display_name
    supplier&.name || wechat_display_name.presence || nickname.presence || "미연결 담당자 #{id}"
  end

  def latest_message
    if wechat_messages.loaded?
      wechat_messages.max_by { |message| [ message.created_at, message.id ] }
    else
      wechat_messages.order(created_at: :desc, id: :desc).first
    end
  end

  def unread_count
    if wechat_messages.loaded?
      return wechat_messages.count { |message| message.direction == "in" && (!last_read_at || message.created_at > last_read_at) }
    end
    scope = wechat_messages.where(direction: "in")
    scope = scope.where("created_at > ?", last_read_at) if last_read_at
    scope.count
  end
end
