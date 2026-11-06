class KakaoRoom < ApplicationRecord
  include AccountScoped

  belongs_to :supplier, optional: true
  has_many :kakao_extractions, dependent: :restrict_with_error
  validate do
    errors.add(:supplier, "거래처와 계정이 일치하지 않습니다") if supplier && supplier.account_id != account_id
  end

  def schedule_extraction!
    with_lock do
      return if extraction_scheduled_at&.future?

      update!(extraction_scheduled_at: 2.minutes.from_now)
      KakaoExtractJob.set(wait_until: extraction_scheduled_at).perform_later(id)
    end
  end

  def alias_names
    aliases.to_s.lines.map(&:strip).reject(&:blank?).uniq
  end

  has_many :kakao_messages, dependent: :restrict_with_error
  validates :name, presence: true, uniqueness: { scope: :account_id }
end
