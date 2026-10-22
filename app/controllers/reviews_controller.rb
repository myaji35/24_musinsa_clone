class ReviewsController < ApplicationController
  def create
    @product = Product.find(params[:product_id])
    review = @product.reviews.new(review_params.merge(user: current_user))

    if review.save
      redirect_to product_path(@product), notice: "리뷰가 등록되었습니다."
    else
      redirect_to product_path(@product), alert: review.errors.full_messages.to_sentence
    end
  end

  private

  def review_params
    params.require(:review).permit(:rating, :content, :height, :weight, :size_purchased, :fit, :photo_url)
  end
end
