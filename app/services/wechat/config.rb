module Wechat
  class Config
    def self.app_id = ENV["WECHAT_APP_ID"].to_s
    def self.app_secret = ENV["WECHAT_APP_SECRET"].to_s
    def self.token = ENV["WECHAT_TOKEN"].to_s
    def self.encoding_aes_key = ENV["WECHAT_ENCODING_AES_KEY"].to_s
    def self.template_id = ENV["WECHAT_PO_TEMPLATE_ID"].to_s
    def self.mac_auto_send? = ENV["WECHAT_MAC_AUTO_SEND"] == "true"
    def self.send_enabled? = ENV["WECHAT_SEND_ENABLED"] == "true"

    def self.status
      { "앱ID" => app_id.present?, "시크릿" => app_secret.present?, "토큰" => token.present?,
        "AES키" => encoding_aes_key.present?, "템플릿" => template_id.present? }
    end

    def self.redact(value)
      [ app_secret, token, encoding_aes_key, app_id ].reject(&:blank?).reduce(value.to_s) { |text, secret| text.gsub(secret, "[FILTERED]") }
    end

    def self.server_url
      Rails.application.routes.url_helpers.wechat_webhook_url(**(ENV["APP_HOST"].present? ? { host: ENV["APP_HOST"], protocol: Rails.application.config.action_mailer.default_url_options[:protocol] } : Rails.application.config.action_mailer.default_url_options.symbolize_keys))
    end
  end
end
