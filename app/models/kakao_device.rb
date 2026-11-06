class KakaoDevice < ApplicationRecord
  include AccountScoped

  validates :name, :token_digest, presence: true
  validates :backfill_window, format: { with: /\A(?:[01]\d|2[0-3]):[0-5]\d-(?:[01]\d|2[0-3]):[0-5]\d\z/ }
  validates :backfill_max_rooms, :backfill_limit_per_room, :open_window_poll_seconds, numericality: { only_integer: true, greater_than: 0 }
  validate do
    errors.add(:time_zone, "유효하지 않은 시간대입니다") unless ActiveSupport::TimeZone[time_zone]
  end

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
