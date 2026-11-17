class WechatController < ApplicationController
  before_action :set_contact, only: [:show, :update, :send_message]

  def index
    @contacts = contact_scope.includes(:supplier, :wechat_messages).order(last_inbound_at: :desc, id: :desc)
  end

  def show
    @contact.update!(last_read_at: Time.current)
    @messages = @contact.wechat_messages.order(:created_at, :id)
    @suppliers = supplier_scope.order(:name)
  end

  def update
    supplier = supplier_scope.find(params[:supplier_id]) if params[:supplier_id].present?
    @contact.update!(supplier: supplier)
    redirect_to wechat_path(@contact), notice: "거래처를 연결했습니다."
  end

  def send_message
    message = Wechat::Client.new.send_text(contact: @contact, content: params[:content].to_s, sent_by: current_user)
    redirect_to wechat_path(@contact), notice: "위챗: #{message.status}"
  rescue ActiveRecord::RecordInvalid
    redirect_to wechat_path(@contact), alert: "본문은 1~2000자로 입력해 주세요."
  end

  private

  def contact_scope
    WechatContact.for_account(current_account || Account.primary)
  end

  def set_contact
    @contact = contact_scope.find(params[:id])
  end
end
