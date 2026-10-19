class ProductCutoutsController < ApplicationController
  before_action :set_product

  def show
    render partial: "products/cutout_panel", locals: { product: @product }
  end

  def create
    unless @product.image.attached?
      return redirect_to_panel(alert: "먼저 원본 이미지를 업로드해 주세요.")
    end

    unless @product.image_processings.cutouts.in_progress.exists?
      processing = @product.image_processings.create!(kind: "cutout")
      ProductImageProcessingJob.perform_later(processing.id)
    end
    redirect_to_panel notice: "배경 제거를 시작했습니다."
  end

  def update
    adopted = ActiveModel::Type::Boolean.new.cast(params[:adopted])
    if adopted && !@product.cutout_image.attached?
      return redirect_to_panel(alert: "채택할 누끼 이미지가 없습니다.")
    end

    @product.update!(cutout_adopted: adopted)
    notice = adopted ? "누끼 이미지를 대표 이미지로 채택했습니다." : "원본 이미지를 대표 이미지로 되돌렸습니다."
    redirect_to_panel notice: notice
  end

  private

  # 패널(Turbo Frame) 안에서 누른 버튼은 패널만 갱신되고 플래시가 보이지 않아
  # 다음 전체 화면에 뒤늦게 뜬다. 프레임 요청에는 플래시를 싣지 않는다.
  def redirect_to_panel(flash_message)
    options = turbo_frame_request? ? {} : flash_message
    redirect_to edit_product_path(@product, anchor: "cutout"), **options
  end

  def set_product
    @product = Product.find(params[:product_id])
  end
end
