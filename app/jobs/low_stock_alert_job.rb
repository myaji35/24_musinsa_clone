# Epic 5.1: 재고 부족 자동 알림 Job
# Solid Queue의 Recurring Job으로 매일 정기 실행
# 재고가 최소 수준 이하인 Variant를 찾아 Claude AI로 알림 메시지 생성
class LowStockAlertJob < ApplicationJob
  queue_as :default

  # 재고 부족 체크 및 알림 생성
  def perform
    Rails.logger.info "⏰ LowStockAlertJob 실행 시작: #{Time.current}"

    low_stock_variants = Variant.where("stock <= min_stock")
                                .where.not(min_stock: nil)
                                .includes(:product)

    Rails.logger.info "📦 재고 부족 상품: #{low_stock_variants.count}개"

    low_stock_variants.each do |variant|
      # 중복 알림 방지: 24시간 이내에 이미 알림을 보냈는지 확인
      if Notification.already_sent_recently?(variant.id, "low_stock", 24)
        Rails.logger.info "⏭️ 건너뜀: #{variant.product.name} (#{variant.color}/#{variant.size}) - 최근 알림 발송됨"
        next
      end

      # Claude AI로 알림 메시지 생성
      message = ClaudeBot::MessageGenerator.generate_low_stock_alert(variant)

      # Notification 생성
      notification = Notification.create!(
        variant: variant,
        notification_type: "low_stock",
        message: message,
        status: "pending"
      )

      Rails.logger.info "✅ 알림 생성: #{variant.product.name} (#{variant.color}/#{variant.size}) - Notification ##{notification.id}"

      # 실제 발송 처리 (예: Slack, Email 등)
      send_notification(notification)
    end

    Rails.logger.info "✨ LowStockAlertJob 실행 완료: #{Time.current}"
  end

  private

  # 실제 알림 발송 (Email + Slack)
  def send_notification(notification)
    begin
      variant = notification.variant

      # 1. Email 발송
      NotificationMailer.low_stock_alert(
        variant: variant,
        message: notification.message
      ).deliver_later

      # 2. Slack 알림
      Notifications::SlackNotifier.call(
        channel: "#inventory",
        text: "⚠️ 재고 부족: #{variant.product.name} (#{variant.color}/#{variant.size}) - 현재 #{variant.stock}개"
      )

      # 발송 성공 처리
      notification.mark_as_sent!
      Rails.logger.info "✅ 알림 발송 완료: Notification ##{notification.id}"

    rescue StandardError => e
      Rails.logger.error "❌ 알림 발송 실패: #{e.message}"
      notification.mark_as_failed!
    end
  end
end
