class InventoryController < ApplicationController
  before_action :set_variant_by_barcode, only: [ :create_stock_in, :create_stock_out ]

  # GET /inventory/scan - 바코드 스캔 페이지
  def scan
    # 모바일 전용 바코드 스캔 UI
  end

  # GET /inventory/stock_in - 입고 폼
  def stock_in
    @variant = Variant.find_by(barcode: params[:barcode]) if params[:barcode].present?
    @stock_log = StockLog.new(log_type: "in")
  end

  # POST /inventory/stock_in - 입고 처리
  def create_stock_in
    @stock_log = @variant.stock_logs.build(stock_in_params)
    @stock_log.log_type = "in"

    if @stock_log.save
      redirect_to stock_in_inventory_index_path(barcode: @variant.barcode), notice: "입고 처리 완료 (재고: #{@variant.stock})"
    else
      render :stock_in, status: :unprocessable_entity
    end
  end

  # GET /inventory/stock_out - 출고 폼
  def stock_out
    @variant = Variant.find_by(barcode: params[:barcode]) if params[:barcode].present?
    @stock_log = StockLog.new(log_type: "out")
  end

  # POST /inventory/stock_out - 출고 처리
  def create_stock_out
    @stock_log = @variant.stock_logs.build(stock_out_params)
    @stock_log.log_type = "out"

    # 재고 부족 검증
    if @variant.stock.to_i < @stock_log.quantity
      flash.now[:alert] = "재고 부족: 현재고 #{@variant.stock}개, 요청 #{@stock_log.quantity}개"
      render :stock_out, status: :unprocessable_entity
      return
    end

    if @stock_log.save
      redirect_to stock_out_inventory_index_path(barcode: @variant.barcode), notice: "출고 처리 완료 (잔여: #{@variant.stock})"
    else
      render :stock_out, status: :unprocessable_entity
    end
  end

  # GET /inventory/history - 재고 이력 조회
  def history
    @variant = Variant.find(params[:variant_id]) if params[:variant_id].present?

    if @variant
      @stock_logs = @variant.stock_logs.recent
    else
      @stock_logs = StockLog.includes(:variant).recent.limit(100)
    end

    # 날짜 필터
    if params[:start_date].present? && params[:end_date].present?
      @stock_logs = @stock_logs.by_date_range(params[:start_date], params[:end_date])
    end

    # CSV 내보내기
    respond_to do |format|
      format.html
      format.csv { send_data stock_logs_to_csv(@stock_logs), filename: "stock_logs_#{Date.today}.csv" }
    end
  end

  # POST /inventory/find_variant - 바코드로 Variant 찾기 (AJAX)
  def find_variant
    @variant = Variant.includes(:product).find_by(barcode: params[:barcode])

    respond_to do |format|
      if @variant
        format.json { render json: { variant: @variant, product: @variant.product } }
      else
        format.json { render json: { error: "Variant not found" }, status: :not_found }
      end
    end
  end

  private

  def set_variant_by_barcode
    barcode = params.dig(:stock_log, :barcode) || params[:barcode]
    @variant = Variant.find_by(barcode: barcode)

    unless @variant
      flash[:alert] = "바코드를 찾을 수 없습니다: #{barcode}"
      redirect_back(fallback_location: root_path)
    end
  end

  def stock_in_params
    params.require(:stock_log).permit(:quantity, :supplier, :unit_cost, :note, :barcode)
  end

  def stock_out_params
    params.require(:stock_log).permit(:quantity, :order_id, :note, :barcode)
  end

  def stock_logs_to_csv(stock_logs)
    require "csv"

    CSV.generate(headers: true) do |csv|
      csv << [ "일시", "유형", "상품명", "바코드", "수량", "사입처", "단가", "메모" ]

      stock_logs.each do |log|
        csv << [
          log.created_at.strftime("%Y-%m-%d %H:%M"),
          log.log_type == "in" ? "입고" : "출고",
          log.variant.product.name,
          log.variant.barcode,
          log.quantity,
          log.supplier,
          log.unit_cost,
          log.note
        ]
      end
    end
  end
end
