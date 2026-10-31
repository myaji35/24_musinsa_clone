class Feedbacks::PurgeContactsJob < ApplicationJob
  queue_as :default

  def perform
    count = 0
    Feedback.contact_purgeable.find_each do |feedback|
      feedback.with_lock do
        if Feedback.contact_purgeable.exists?(feedback.id)
          feedback.update!(contact_email: nil, contact_purged_at: Time.current)
          count += 1
        end
      end
    end
    Rails.logger.info("의견 연락처 파기 완료: #{count}건")
    count
  end
end
