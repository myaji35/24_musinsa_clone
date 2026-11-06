class KakaoMessage < ApplicationRecord
  include AccountScoped

  SOURCES = %w[notification backfill open_window].freeze
  has_many :kakao_message_external_ids, dependent: :delete_all
  belongs_to :kakao_room
  belongs_to :kakao_device, optional: true
  validates :body, presence: true, length: { maximum: 5000 }
  validate :matching_account
  before_validation do
    self.body = self.class.normalize(body) if body
    self.match_key = self.class.key_for(body) if body
  end

  def self.normalize(body)
    body.unicode_normalize(:nfc).gsub(/[[:space:]]+/, " ").strip
  end

  def self.key_for(body)
    Digest::SHA256.hexdigest(normalize(body).first(60))
  end

  def self.ingest!(device:, room:, source:, messages:)
    raise ArgumentError, "수집 경로가 유효하지 않습니다" unless SOURCES.include?(source)
    # Validate the complete batch before writing any records.
    entries = messages.map do |entry|
      data = entry.to_h.symbolize_keys.slice(:external_id, :author, :body, :sent_at, :time_precision, :truncated, :is_mine)
      raise ArgumentError, "내용은 1~5000자여야 합니다" unless data[:body].is_a?(String) && data[:body].length.between?(1, 5000) && normalize(data[:body]).present?
      raw_time = data[:sent_at]
      raise ArgumentError, "시간대가 있는 ISO8601 시각이 필요합니다" unless raw_time.is_a?(String) && raw_time.match?(/T.*(?:Z|[+-]\d{2}:\d{2})\z/)
      data[:sent_at] = Time.iso8601(raw_time)
      raise ArgumentError, "시각 정밀도가 유효하지 않습니다" unless %w[second minute].include?(data[:time_precision])
      data[:external_id] = data[:external_id].presence
      data
    end
    counts = { received: entries.size, created: 0, merged: 0, duplicates: 0 }
    transaction do
      device.lock!
      entries.each do |data|
        scope = where(account_id: device.account_id)
        if data[:external_id] && KakaoMessageExternalId.where(account_id: device.account_id, external_id: data[:external_id]).exists?
          counts[:duplicates] += 1
          next
        end
        existing = scope.where(kakao_room: room, author: data[:author], match_key: key_for(data[:body]))
                        .where(sent_at: (data[:sent_at] - 10.minutes)..(data[:sent_at] + 10.minutes)).reject { |candidate| candidate.sources.to_s.split(",").include?(source) }
                        .min_by { |candidate| [ (candidate.sent_at - data[:sent_at]).abs, candidate.id ] }
        if existing
          existing.merge_ingestion!(data, source)
          counts[:merged] += 1
        else
          message = create!(data.merge(account: device.account, kakao_room: room, kakao_device: device, source: source, sources: source))
          message.record_external_id!(data[:external_id])
          counts[:created] += 1
        end
      end
      room.update!(last_collected_at: Time.current, last_message_count: entries.size)
      device.update!(last_seen_at: Time.current, last_collected_at: Time.current)
    end
    counts
  end

  def merge_ingestion!(data, incoming_source)
    if truncated? && !ActiveModel::Type::Boolean.new.cast(data[:truncated])
      self.body = data[:body]
      self.truncated = false
      self.needs_extraction = true
    end
    same_minute = sent_at.to_i / 60 == data[:sent_at].to_i / 60
    if %w[backfill open_window].include?(incoming_source)
      unless same_minute && time_precision == "second"
        self.sent_at = data[:sent_at]
        self.time_precision = data[:time_precision]
      end
    elsif same_minute && data[:time_precision] == "second"
      self.sent_at = data[:sent_at]
      self.time_precision = "second"
    end
    self.sources = (sources.to_s.split(",") + [ incoming_source ]).uniq.join(",")
    self.external_id ||= data[:external_id]
    save!
    record_external_id!(data[:external_id])
  end

  def record_external_id!(external_id)
    return unless external_id

    kakao_message_external_ids.create!(account_id: account_id, external_id: external_id)
  end

  private

  def matching_account
    errors.add(:account, "방과 기기의 계정이 일치해야 합니다") if kakao_room&.account_id != account_id || (kakao_device && kakao_device.account_id != account_id)
  end
end
