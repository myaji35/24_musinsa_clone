module Webhooks
  class WechatController < ApplicationController
    skip_before_action :require_admin
    skip_forgery_protection

    def verify
      Wechat::Protocol.verify!(signature: params[:signature], timestamp: params[:timestamp], nonce: params[:nonce])
      render plain: params[:echostr].to_s
    rescue Wechat::Protocol::Invalid
      head :forbidden
    end

    def receive
      if params[:encrypt_type] == "aes"
        envelope = Wechat::Protocol.parse(request.raw_post)
        Wechat::Protocol.verify!(signature: params[:msg_signature], timestamp: params[:timestamp], nonce: params[:nonce], encrypted: envelope.fetch("Encrypt", ""))
        data = Wechat::Protocol.parse(Wechat::Protocol.decrypt(envelope.fetch("Encrypt", "")))
      else
        Wechat::Protocol.verify!(signature: params[:signature], timestamp: params[:timestamp], nonce: params[:nonce])
        data = Wechat::Protocol.parse(request.raw_post)
      end
      Wechat::Inbound.call(data)
      render plain: "success"
    rescue Wechat::Protocol::Invalid
      head :forbidden
    end
  end
end
