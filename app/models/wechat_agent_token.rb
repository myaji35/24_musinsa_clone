require "digest"

class WechatAgentToken < ApplicationRecord
  include AccountScoped
  validates :name, presence: true, length: { maximum: 100 }
  validates :token_digest, presence: true, uniqueness: true
  scope :active, -> { where(revoked_at: nil) }

  def self.issue!(account:, name:)
    raw = SecureRandom.hex(32)
    [ create!(account: account, name: name, token_digest: Digest::SHA256.hexdigest(raw)), raw ]
  end
end
