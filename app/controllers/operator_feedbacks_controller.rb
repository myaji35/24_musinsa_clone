class OperatorFeedbacksController < ApplicationController
  def create
    feedback = feedback_account.feedbacks.new(params.require(:feedback).permit(:kind, :body, :page_url, :manual_chapter))
    feedback.assign_attributes(source: "operator", user: current_user)
    if feedback.save
      render json: { message: "의견을 받았어요" }, status: :created
    else
      render json: { message: feedback.errors.full_messages.join(" · ") }, status: :unprocessable_entity
    end
  end

  private

  def feedback_account
    current_account || Account.primary
  end
end
