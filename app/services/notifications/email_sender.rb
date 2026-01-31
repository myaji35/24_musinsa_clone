# Service for sending email notifications
module Notifications
  class EmailSender < BaseNotifier
    def initialize(to:, subject:, body:, from: nil)
      @to = to
      @subject = subject
      @body = body
      @from = from || ENV["DEFAULT_FROM_EMAIL"] || "noreply@jieun-fashion.com"
    end

    def call
      return mock_send unless notification_enabled?

      begin
        # ActionMailer를 사용한 실제 이메일 발송
        NotificationMailer.generic_notification(
          to: @to,
          from: @from,
          subject: @subject,
          body: @body
        ).deliver_later

        log_notification("Email", @body, "sent")
        success({ to: @to, subject: @subject })
      rescue StandardError => e
        Rails.logger.error "EmailSender Error: #{e.message}"
        failure("이메일 발송 실패: #{e.message}")
      end
    end

    private

    def mock_send
      log_notification("Email (Mock)", @body, "mocked")
      success({
        to: @to,
        subject: @subject,
        note: "Mock mode - email not actually sent. Set ENABLE_NOTIFICATIONS=true to send real emails."
      })
    end
  end
end
