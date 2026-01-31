# Base class for all notification services
module Notifications
  class BaseNotifier < ApplicationService
    def notify(message:, **options)
      raise NotImplementedError, "Subclasses must implement #notify method"
    end

    protected

    def log_notification(channel, message, status)
      Rails.logger.info "[#{self.class.name}] Channel: #{channel}, Status: #{status}, Message: #{message.truncate(100)}"
    end

    def notification_enabled?
      Rails.env.production? || ENV["ENABLE_NOTIFICATIONS"] == "true"
    end
  end
end
