# Epic 6.1: 마케팅 캠페인 자동 발송 Job
# Solid Queue의 Recurring Job으로 정기 실행
# 예약된 캠페인을 찾아 자동 발송
class SendCampaignJob < ApplicationJob
  queue_as :default

  # 예약된 캠페인 발송
  def perform
    Rails.logger.info "📢 SendCampaignJob 실행 시작: #{Time.current}"

    # 발송 대기 중인 캠페인 찾기
    pending_campaigns = Campaign.pending_send

    Rails.logger.info "📧 발송 대기 캠페인: #{pending_campaigns.count}개"

    pending_campaigns.each do |campaign|
      begin
        Rails.logger.info "🚀 캠페인 발송 시작: #{campaign.name} (ID: #{campaign.id})"

        # 캠페인 발송
        campaign.send_campaign!

        Rails.logger.info "✅ 캠페인 발송 완료: #{campaign.name} - #{campaign.sent_count}명 발송"
      rescue StandardError => e
        Rails.logger.error "❌ 캠페인 발송 실패: #{campaign.name} - #{e.message}"
        campaign.update(status: "cancelled")
      end
    end

    Rails.logger.info "✨ SendCampaignJob 실행 완료: #{Time.current}"
  end
end
