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
    result = Inventory::StockAdjuster.call(
      barcode: @variant.barcode,
      quantity: stock_in_params[:quantity],
      stock_type: "in",
      note: stock_in_params[:note],
      user_name: current_user_name
    )

    if result.success?
      redirect_to inventory_stock_in_path(barcode: @variant.barcode),
                  notice: result.data[:message]
    else
      # 실패한 입력값과 오류를 유지하여 폼을 다시 표시
      @stock_log = StockLog.new(stock_in_params.except(:barcode))
      @stock_log.variant = @variant
      @stock_log.log_type = "in"
      @stock_log.errors.add(:base, result.error)
      params[:barcode] = @variant.barcode
      flash.now[:alert] = result.error
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
    result = Inventory::StockAdjuster.call(
      barcode: @variant.barcode,
      quantity: stock_out_params[:quantity],
      stock_type: "out",
      note: stock_out_params[:note],
      user_name: current_user_name
    )

    if result.success?
      redirect_to inventory_stock_out_path(barcode: @variant.barcode),
                  notice: result.data[:message]
    else
      # 실패한 입력값과 오류를 유지하여 폼을 다시 표시
      @stock_log = StockLog.new(stock_out_params.except(:barcode))
      @stock_log.variant = @variant
      @stock_log.log_type = "out"
      @stock_log.errors.add(:base, result.error)
      params[:barcode] = @variant.barcode
      flash.now[:alert] = result.error
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
    result = Inventory::BarcodeScanner.call(barcode: params[:barcode])

    respond_to do |format|
      if result.success?
        format.json { render json: result.data }
      else
        format.json { render json: { error: result.error }, status: :not_found }
      end
    end
  end

  private

  def current_user_name
    # TODO: 실제 사용자 인증 시스템 연동 시 수정
    "Admin"
  end

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
