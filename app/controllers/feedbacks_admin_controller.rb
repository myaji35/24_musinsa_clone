class FeedbacksAdminController < ApplicationController
  before_action :set_feedback, only: [ :show, :update ]

  def index
    @feedbacks = feedback_scope.includes(:user).order(created_at: :desc, id: :desc)
    @feedbacks = @feedbacks.where(status: params[:status]) if params[:status].present?
    @feedbacks = @feedbacks.where(kind: params[:kind]) if params[:kind].present?
    @feedbacks = @feedbacks.where(source: Feedback::SOURCES.fetch(params[:source], [])) if params[:source].present?
    @feedbacks = @feedbacks.where(manual_chapter: params[:manual_chapter]) if params[:manual_chapter].present?
    @feedbacks = @feedbacks.limit(200)
  end

  def show
  end

  def update
    attributes = params.require(:feedback).permit(:status, :handling_note)
    unless Feedback::STATUSES.value?(attributes[:status])
      @feedback.errors.add(:status, "를 확인해 주세요")
      render :show, status: :unprocessable_entity
      return
    end
    attributes[:answered_at] = %w[answered closed].include?(attributes[:status]) ? (@feedback.answered_at || Time.current) : nil
    if @feedback.update(attributes)
      redirect_to feedbacks_admin_path(@feedback), notice: "처리 내용을 저장했어요"
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def feedback_scope
    (current_account || Account.primary).feedbacks
  end

  def set_feedback
    @feedback = feedback_scope.find(params[:id])
  end
end
