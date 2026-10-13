class ProductAnalysesController < ApplicationController
  def index
    @characters = Character.order(:age_band, :id)
    products = Product.includes(:latest_analysis, :image_attachment).order(created_at: :desc)
    products = products.where(supplier_import_id: params[:supplier_import_id]) if params[:supplier_import_id].present?
    @calculator = Kpi::Calculator.new
    @rows = @calculator.rows(products)
    @rows.select! { |row| row.analysis&.character_id.to_s == params[:character_id] } if params[:character_id].present?
    @rows.select! { |row| (row.analysis&.status || "unanalysed") == params[:status] } if params[:status].present?
  end

  def show
    @analysis = ProductAnalysis.includes(:product, :character, :alt_character).find(params[:id])
    @history = @analysis.product.product_analyses.includes(:character).order(created_at: :desc)
    @characters = Character.order(:age_band, :id)
    @row = Kpi::Calculator.new.row(@analysis.product)
  end

  def create
    product = Product.find(params[:product_id])
    analysis = product.product_analyses.create!
    if enqueue_analysis(analysis)
      redirect_to product_analysis_path(analysis), notice: "상품 분석을 접수했습니다."
    else
      redirect_to product_analyses_path, alert: analysis.error_message
    end
  end

  def analyze_pending
    scope = Product.where.not(id: ProductAnalysis.select(:product_id))
    scope = scope.where(supplier_import_id: params[:supplier_import_id]) if params[:supplier_import_id].present?
    count = 0
    scope.order(:id).limit(50).each do |product|
      analysis = product.product_analyses.create!
      unless enqueue_analysis(analysis)
        return redirect_to product_analyses_path(supplier_import_id: params[:supplier_import_id]), alert: analysis.error_message
      end
      count += 1
    end
    redirect_to product_analyses_path(supplier_import_id: params[:supplier_import_id]), notice: "미분석 상품 #{count}건을 접수했습니다."
  end

  def update
    analysis = ProductAnalysis.find(params[:id])
    attributes = params.require(:product_analysis).permit(:target_units_override, :character_id)
    attributes[:target_units_override] = nil if attributes.key?(:target_units_override) && attributes[:target_units_override].blank?
    if attributes[:character_id].present? && !Character.exists?(id: attributes[:character_id])
      return redirect_to product_analysis_path(analysis), alert: "로스터에 없는 캐릭터입니다."
    end

    analysis.assign_attributes(attributes)
    analysis.manually_assigned = analysis.character_id.present? || analysis.target_units_override.present?
    if analysis.save
      Kpi::Calculator.new.assign_target!(analysis) if analysis.status == "done" || analysis.manually_assigned?
      redirect_to product_analysis_path(analysis), notice: "분석 설정을 저장했습니다."
    else
      redirect_to product_analysis_path(analysis), alert: analysis.errors.full_messages.to_sentence
    end
  end

  private

  def enqueue_analysis(analysis)
    ProductAnalysisJob.perform_later(analysis.id)
    true
  rescue SolidQueue::Job::EnqueueError, ActiveRecord::StatementInvalid => e
    Rails.logger.error "상품 분석 작업 등록 실패 (#{analysis.id}): #{e.class}: #{e.message}"
    analysis.update!(status: "failed", error_message: "작업 등록 실패(DB 잠김)")
    false
  end
end
