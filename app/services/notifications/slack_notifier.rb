# Service for sending Slack notifications
module Notifications
  class SlackNotifier < BaseNotifier
    WEBHOOK_URL = ENV["SLACK_WEBHOOK_URL"]

    def initialize(channel:, text:, username: "JIEUN Bot", icon_emoji: ":robot_face:")
      @channel = channel
      @text = text
      @username = username
      @icon_emoji = icon_emoji
    end

    def call
      return mock_send unless notification_enabled? && WEBHOOK_URL.present?

      begin
        response = HTTP.post(WEBHOOK_URL, json: payload)

        if response.status.success?
          log_notification("Slack:#{@channel}", @text, "sent")
          success({ channel: @channel, text: @text })
        else
          failure("Slack API Error: #{response.status}")
        end
      rescue StandardError => e
        Rails.logger.error "SlackNotifier Error: #{e.message}"
        failure("Slack 알림 실패: #{e.message}")
      end
    end

    private

    def payload
      {
        channel: @channel,
        username: @username,
        text: @text,
        icon_emoji: @icon_emoji
      }
    end

    def mock_send
      log_notification("Slack:#{@channel} (Mock)", @text, "mocked")
      success({
        channel: @channel,
        text: @text,
        note: "Mock mode - Slack message not sent. Set SLACK_WEBHOOK_URL to enable."
      })
    end
  end
end
