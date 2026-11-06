class KakaoExtractionMessage < ApplicationRecord
  include AccountScoped
  belongs_to :kakao_extraction
  belongs_to :kakao_message
  validates :kakao_message_id, uniqueness: { scope: :kakao_extraction_id }
  validate do
    if kakao_extraction && kakao_message && (account_id != kakao_extraction.account_id || account_id != kakao_message.account_id || kakao_extraction.kakao_room_id != kakao_message.kakao_room_id)
      errors.add(:account, "근거 메시지의 계정과 방이 일치해야 합니다")
    end
  end
end
