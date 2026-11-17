require "net/http"
require "json"

module Wechat
  class Client
    TOKEN_ERRORS = [ 40001, 42001, 40014 ].freeze
    WINDOW_CLOSED = "48시간 창 닫힘 — 담당자가 공식계정에 메시지를 한 번 보내야 함".freeze

    # HTTP callable accepts a URI and JSON hash; tests inject an in-memory fake.
    def initialize(http: nil, cache: Rails.cache)
      @http = http || method(:post_json)
      @cache = cache
      @access_tokens = []
    end

    def send_text(contact:, content:, purchase_order: nil, sent_by: nil, template_data: nil)
      message = contact.wechat_messages.build(account: contact.account, direction: "out", msg_type: "text",
        content: content, purchase_order: purchase_order, sent_by: sent_by, status: "disabled")
      mode = contact.account.wechat_channel_mode
      message.status = { "manual" => "pending_manual", "mac_app" => (Config.mac_auto_send? ? "awaiting_approval" : "pending_manual") }.fetch(mode, "disabled")
      message.save! # Validate before any HTTP request.
      return message unless mode == "official"
      return message unless Config.send_enabled?
      if contact.open_id.blank?
        message.update!(status: "failed", error: "공식계정 open_id가 필요합니다")
        return message
      end
      unless contact.subscribed?
        message.update!(status: "window_closed", error: WINDOW_CLOSED)
        return message
      end
      if contact.window_open?
        path = "message/custom/send"
        payload = { touser: contact.open_id, msgtype: "text", text: { content: content } }
      elsif purchase_order && Config.template_id.present?
        path = "message/template/send"
        payload = { touser: contact.open_id, template_id: Config.template_id,
          url: purchase_order.confirmation_url, data: template_data || {} }
        message.update!(msg_type: "template")
      else
        message.update!(status: "window_closed", error: WINDOW_CLOSED)
        return message
      end
      begin
        result = request(path, payload)
        if result.fetch("errcode", 0).to_i.zero?
          message.update!(status: "sent", wechat_msg_id: result["msgid"]&.to_s)
        else
          message.update!(status: "failed", error: "#{result['errcode'].to_i}: #{redact_error(result["errmsg"])}")
        end
      rescue StandardError
        # HTTP exceptions can contain URLs/access tokens. Never persist or log them.
        message.update!(status: "failed", error: "위챗 API 요청 실패 (설정·네트워크 확인)")
      end
      message
    end

    private

    def cache_key = "wechat/stable_token/#{Digest::SHA256.hexdigest(Config.app_id)}"

    def access_token(refresh: false)
      @cache.delete(cache_key) if refresh
      cached = @cache.read(cache_key)
      return cached if cached.present?
      raise "WeChat credentials missing" if Config.app_id.blank? || Config.app_secret.blank?
      result = @http.call(URI("https://api.weixin.qq.com/cgi-bin/stable_token"),
        { grant_type: "client_credential", appid: Config.app_id, secret: Config.app_secret, force_refresh: refresh })
      token = result["access_token"]
      raise "WeChat token unavailable" if token.blank?
      ttl = result.fetch("expires_in", 7200).to_i - 300
      @cache.write(cache_key, token, expires_in: ttl) if ttl.positive?
      token
    end

    def request(path, payload)
      token = access_token
      @access_tokens << token
      result = @http.call(api_uri(path, token), payload)
      if TOKEN_ERRORS.include?(result["errcode"].to_i)
        token = access_token(refresh: true)
        @access_tokens << token
        result = @http.call(api_uri(path, token), payload)
      end
      result
    end

    def redact_error(value)
      @access_tokens.reduce(Config.redact(value)) { |text, token| text.gsub(token, "[FILTERED]") }.truncate(500)
    end

    def api_uri(path, token)
      URI("https://api.weixin.qq.com/cgi-bin/#{path}?#{URI.encode_www_form(access_token: token)}")
    end

    def post_json(uri, payload)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 5, write_timeout: 5) { |http| http.request(request) }
      raise "WeChat HTTP failure" unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    end
  end
end
