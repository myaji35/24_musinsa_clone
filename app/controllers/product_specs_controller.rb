class ProductSpecsController < ApplicationController
  def index
    @products = Product.includes(:variants).order(:id).sort_by { |product| product.product_spec.completion_rate }
    @complete_count = @products.count { |product| product.product_spec.complete? }
  end

  def edit
    @product = Product.find(params[:product_id])
  end

  def update
    @product = Product.find(params[:product_id])
    incoming = params.require(:product).permit(spec: [ :weight_g, :note, { material: ProductSpec::MATERIAL_FIELDS, fit: [ *ProductSpec::FIT_OPTIONS.keys.excluding("계절"), { 계절: [] } ], measurements: {} } ]).to_h.fetch("spec", {})
    @product.spec = (@product.spec || {}).deep_merge(incoming)
    if @product.save
      redirect_to edit_product_spec_path(@product), notice: "상세스펙을 저장했습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
