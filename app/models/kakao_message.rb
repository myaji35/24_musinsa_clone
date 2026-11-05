class KakaoMessage < ApplicationRecord
  include AccountScoped

  belongs_to :kakao_room
  belongs_to :kakao_device, optional: true
  validates :body, presence: true, length: { maximum: 5000 }
  validates :digest, presence: true, uniqueness: { scope: :account_id }
  validate :matching_account
  before_validation :prepare_message

  def self.message_digest(room, message)
    Digest::SHA256.hexdigest(room + "\u0000" + %w[author date time_raw].map { |key| message[key].to_s }.join + message["body"].to_s.unicode_normalize(:nfc).strip)
  end

  def self.message_time(date, raw)
    match = /\A(오전|오후) (\d{1,2}):(\d{2})\z/.match(raw.to_s)
    return unless match && (1..12).cover?(match[2].to_i) && (0..59).cover?(match[3].to_i)
    day = Date.iso8601(date.to_s)
    hour = match[2].to_i % 12 + (match[1] == "오후" ? 12 : 0)
    ActiveSupport::TimeZone["Seoul"].local(day.year, day.month, day.day, hour, match[3].to_i)
  rescue ArgumentError
    nil
  end

  private

  def prepare_message
    self.body = body.unicode_normalize(:nfc).strip if body
    self.digest ||= self.class.message_digest(kakao_room.name, { "author" => author, "date" => sent_on&.iso8601, "time_raw" => time_raw, "body" => body }) if kakao_room
    self.sent_at ||= self.class.message_time(sent_on&.iso8601, time_raw)
  end

  def matching_account
    errors.add(:account, "방과 기기의 계정이 일치해야 합니다") if kakao_room&.account_id != account_id || (kakao_device && kakao_device.account_id != account_id)
  end
end
