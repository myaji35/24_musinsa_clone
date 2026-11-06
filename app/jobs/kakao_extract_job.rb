class KakaoExtractJob < ApplicationJob
  def perform(room_id)
    room = KakaoRoom.find_by(id: room_id)
    return unless room

    room.update!(extraction_scheduled_at: nil)
    result = Kakao::Extractor.call(room)
    room.schedule_extraction! if result.success? && room.kakao_messages.where(needs_extraction: true).exists?
  end
end
