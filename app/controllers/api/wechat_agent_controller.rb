module Api
  class WechatAgentController < ActionController::API
    before_action :authenticate_agent
    rescue_from ActiveRecord::RecordInvalid, ActionController::ParameterMissing, ArgumentError do
      head :unprocessable_entity
    end

    def outbox
      return render json: [] unless Wechat::Config.mac_auto_send?
      render json: @account.wechat_messages.where(status: "queued_mac").includes(:wechat_contact).order(:id).limit(30).map { |message|
        { id: message.id, display_name: message.wechat_contact.wechat_display_name, content: message.content }
      }
    end

    def result
      message = @account.wechat_messages.find(params[:id])
      message.with_lock do
        return head :conflict unless message.status == "queued_mac"
        return head :unprocessable_entity unless [ true, false ].include?(params[:ok])
        message.update!(status: params[:ok] ? "sent_mac" : "failed", error: params[:ok] ? nil : params[:error].to_s.truncate(500))
      end
      head :no_content
    end

    def inbox
      key = params.require(:external_key).to_s
      name = params.require(:display_name).to_s.strip
      return head :unprocessable_entity if key.blank? || name.blank?
      @account.with_lock do
        unless @account.wechat_messages.exists?(external_key: key)
          contact = @account.wechat_contacts.find_or_create_by!(wechat_display_name: name)
          received_at = params[:received_at].present? ? Time.iso8601(params[:received_at]) : Time.current
          contact.wechat_messages.create!(account: @account, direction: "in", msg_type: "text", status: "received_mac", content: params.require(:content), external_key: key, received_at: received_at)
          contact.update!(last_inbound_at: Time.current)
        end
      end
      head :no_content
    end

    def heartbeat
      @token.update!(last_seen_at: Time.current)
      head :no_content
    end

    private

    def authenticate_agent
      scheme, raw = request.authorization.to_s.split(" ", 2)
      @token = WechatAgentToken.active.find_by(token_digest: Digest::SHA256.hexdigest(raw.to_s)) if scheme == "Bearer" && raw.present?
      @account = @token&.account
      head :unauthorized unless @account&.wechat_channel_mode == "mac_app"
    end
  end
end
