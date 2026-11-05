class KakaoDevice < ApplicationRecord
  include AccountScoped

  validates :name, :token_digest, presence: true
  validates :collect_start_hour, :collect_end_hour, inclusion: { in: 0..23 }
  validates :max_rooms_per_run, inclusion: { in: 1..10 }

  def self.issue!(account:, name:)
    token = SecureRandom.urlsafe_base64(32)
    [ create!(account: account, name: name, token_digest: Digest::SHA256.hexdigest(token)), token ]
  end

  def self.authenticate(token)
    return if token.blank?
    find_by(token_digest: Digest::SHA256.hexdigest(token), revoked_at: nil)
  end

  def connection_status
    return "폐기" if revoked_at
    return "연결 안 됨" if last_seen_at.nil? || last_seen_at < 24.hours.ago
    last_error.present? ? "오류" : "정상"
  end
end
