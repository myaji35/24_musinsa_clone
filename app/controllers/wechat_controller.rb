class WechatController < ApplicationController
  before_action :set_contact, only: [ :show, :update, :send_message, :receive_message ]

  rescue_from ActiveRecord::RecordInvalid, with: :invalid_record

  def create
    return head :unprocessable_entity if channel_account.wechat_channel_mode == "official"
    supplier = supplier_scope.find(params[:supplier_id]) if params[:supplier_id].present?
    contact = contact_scope.create!(supplier: supplier, wechat_display_name: params.require(:wechat_display_name).strip)
    redirect_to wechat_path(contact)
  end

  def channel
    mode = params.require(:wechat_channel_mode)
    return head :unprocessable_entity unless %w[official manual mac_app].include?(mode)
    channel_account.update!(wechat_channel_mode: mode)
    audit("channel_#{mode}")
    redirect_to wechat_index_path
  end

  def issue_token
    _token, @raw_token = WechatAgentToken.issue!(account: channel_account, name: params[:name])
    audit("token_issued")
    response.headers["Cache-Control"] = "no-store"
    index
    render :index
  end

  def revoke_token
    channel_account.wechat_agent_tokens.find(params[:token_id]).update!(revoked_at: Time.current)
    audit("token_revoked")
    redirect_to wechat_index_path
  end

  def complete
    message = channel_account.wechat_messages.find(params[:message_id])
    message.with_lock do
      target = { "pending_manual" => [ %w[manual mac_app], "sent_manual" ], "awaiting_approval" => [ %w[mac_app], "queued_mac" ] }[message.status]
      return head :conflict unless target && target.first.include?(channel_account.wechat_channel_mode)
      return head :unprocessable_entity if target.last == "queued_mac" && !Wechat::Config.mac_auto_send?
      return head :unprocessable_entity if target.last == "queued_mac" && message.wechat_contact.wechat_display_name.blank?
      message.update!(status: target.last, processed_by: current_user, processed_at: Time.current)
    end
    audit("message_completed_#{message.id}")
    redirect_to wechat_path(message.wechat_contact)
  end

  def receive_message
    return head :unprocessable_entity unless channel_account.wechat_channel_mode == "manual"
    @contact.wechat_messages.create!(account: channel_account, direction: "in", msg_type: "text", content: params[:content], status: "received_manual", received_at: Time.current, processed_by: current_user, processed_at: Time.current)
    @contact.update!(last_inbound_at: Time.current)
    redirect_to wechat_path(@contact)
  end

  def index
    @contacts = contact_scope.includes(:supplier, :wechat_messages).order(last_inbound_at: :desc, id: :desc)
  end

  def show
    @contact.update_columns(last_read_at: Time.current)
    @messages = @contact.wechat_messages.includes(:processed_by).order(:created_at, :id)
    @suppliers = supplier_scope.order(:name)
  end

  def update
    supplier = supplier_scope.find(params[:supplier_id]) if params[:supplier_id].present?
    attributes = { supplier: supplier }
    attributes[:wechat_display_name] = params[:wechat_display_name].to_s.strip if params.key?(:wechat_display_name)
    @contact.update!(attributes)
    redirect_to wechat_path(@contact), notice: "거래처를 연결했습니다."
  end

  def send_message
    message = Wechat::Client.new.send_text(contact: @contact, content: params[:content].to_s, sent_by: current_user)
    redirect_to wechat_path(@contact), notice: "위챗: #{message.status}"
  rescue ActiveRecord::RecordInvalid
    redirect_to wechat_path(@contact), alert: "본문은 1~2000자로 입력해 주세요."
  end

  private

  def channel_account
    current_account || Account.primary
  end

  def audit(event)
    Rails.logger.info("wechat event=#{event} account_id=#{channel_account.id} user_id=#{current_user.id}")
  end

  def invalid_record
    redirect_to wechat_index_path, alert: "입력값을 확인해 주세요."
  end

  def contact_scope
    WechatContact.for_account(current_account || Account.primary)
  end

  def set_contact
    @contact = contact_scope.find(params[:id])
  end
end
