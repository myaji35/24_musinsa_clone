module Wechat
  class Inbound
    def self.call(data)
      raise Protocol::Invalid if data["FromUserName"].blank?
      return unless %w[text image voice event].include?(data["MsgType"])
      return if data["MsgType"] == "event" && !%w[subscribe unsubscribe].include?(data["Event"])
      timestamp = Integer(data.fetch("CreateTime", ""), exception: false)
      raise Protocol::Invalid unless timestamp && timestamp.positive?
      received_at = [Time.at(timestamp), Time.current].min
      message_id = data["MsgId"].presence || "event:#{data['FromUserName']}:#{timestamp}:#{data['Event']}"
      account = Account.primary
      WechatContact.transaction do
        contact = WechatContact.find_or_create_by!(account: account, open_id: data["FromUserName"])
        contact.with_lock do
          return if WechatMessage.exists?(wechat_msg_id: message_id)
          content = data["Content"] || data["Recognition"] || data["Event"]
          contact.wechat_messages.create!(account: account, direction: "in", msg_type: data["MsgType"],
            content: content, media_id: data["MediaId"], wechat_msg_id: message_id, status: "received")
          changes = {}
          # Subscription events alone do not open the customer-service messaging window.
          changes[:last_inbound_at] = [contact.last_inbound_at, received_at].compact.max unless data["MsgType"] == "event"
          changes[:subscribed] = data["Event"] == "subscribe" if data["MsgType"] == "event"
          contact.update!(changes)
        end
      end
    rescue ActiveRecord::RecordNotUnique
      nil # WeChat retries deliveries, including simultaneous deliveries.
    end
  end
end
