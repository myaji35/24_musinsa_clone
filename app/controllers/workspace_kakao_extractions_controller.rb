class WorkspaceKakaoExtractionsController < ApplicationController
  skip_before_action :require_admin
  before_action :require_account_member

  def index
    @extractions = current_account.kakao_extractions.where(status: "pending").includes(:supplier, :kakao_room, :kakao_messages).order(:id)
    %w[kakao_room_id supplier_id kind].each do |field|
      @extractions = @extractions.where(field => params[field]) if params[field].present?
    end
  end

  def show
    @extraction = current_account.kakao_extractions.find(params[:id])
  end

  def gaps
    @messages = current_account.kakao_messages.where(extraction_gap: true).includes(:kakao_room, :kakao_extractions).order(:sent_at)
  end

  def create
    message = current_account.kakao_messages.find(params[:message_id])
    extraction = nil
    message.with_lock do
      extraction = current_account.kakao_extractions.create!(kakao_room: message.kakao_room, supplier: message.kakao_room.supplier, kind: "issue", summary: message.body)
      extraction.kakao_extraction_messages.create!(account: current_account, kakao_message: message)
      message.update!(extraction_gap: false)
    end
    redirect_to workspace_kakao_extraction_path(extraction)
  end

  def approve
    extraction = current_account.kakao_extractions.find(params[:id])
    attributes = params.require(:extraction).permit(:kind, :progress, :summary, :date, :quantity, :unit, :amount, :supplier_id)
    current_account.suppliers.find(attributes[:supplier_id]) if attributes[:supplier_id].present?
    result = Kakao::Reviewer.call(extraction, user: current_user, attributes: attributes, target: params[:target])
    if result.success?
      redirect_to workspace_kakao_inbox_path, notice: "승인했습니다"
    else
      @extraction = extraction
      @error = result.error
      render :show, status: :unprocessable_entity
    end
  end

  def reject
    extraction = current_account.kakao_extractions.find(params[:id])
    extraction.with_lock do
      extraction.update!(status: "rejected", reviewed_by_user: current_user, reviewed_at: Time.current) if extraction.status == "pending"
    end
    redirect_to workspace_kakao_inbox_path
  end
end
