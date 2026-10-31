class FeedbacksController < ApplicationController
  skip_before_action :require_admin, only: [ :new, :create ]

  def new
    @feedback = Feedback.new(product_id: params[:product_id], page_url: params[:page_url].presence || request.referer)
  end

  def create
    if params[:website].present?
      # 자동 프로그램이 함정 칸을 채운 경우: 저장하지 않되 정상 접수와 같은 화면을 보여준다
      @feedback = Feedback.new
      flash.now[:notice] = success_message
      render :new
      return
    end

    result = Feedbacks::Receiver.call(feedback_params, source: "customer_web",
                                     ip: request.remote_ip, user_agent: request.user_agent)
    if result.success?
      redirect_to new_feedback_path, notice: success_message
    else
      @feedback = result.error
      render :new, status: :unprocessable_entity
    end
  end

  private

  def success_message
    "의견이 접수되었습니다. 소중한 의견 감사합니다."
  end

  def feedback_params
    params.require(:feedback).permit(:kind, :body, :page_url, :product_id, :contact_email, :contact_consent)
  end
end
