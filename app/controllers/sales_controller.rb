class SalesController < ApplicationController
  def index
    @period = params[:period].presence || "today"
    @to = Date.current
    @from = @to - { "today" => 0, "7" => 6, "30" => 29 }.fetch(@period, 0)
    if @period == "custom"
      begin
        @from = Date.iso8601(params[:from].to_s)
        @to = Date.iso8601(params[:to].to_s)
        raise ArgumentError if @from > @to
      rescue ArgumentError
        flash.now[:alert] = "기간을 올바르게 선택해 주세요"
        @from = @to = Date.current
      end
    end

    sales = Order.where.not(status: "cancelled").where(created_at: @from.beginning_of_day..@to.end_of_day)
    @quantities = sales.group(:variant_id).sum(:quantity)
    @amounts = sales.group(:variant_id).sum(:total_price)
    @variants = Variant.includes(:product).where(id: @quantities.keys).order(:id)
    @low_stock_variants = Variant.includes(:product)
                                 .where("COALESCE(stock, 0) = 0 OR (min_stock IS NOT NULL AND stock <= min_stock)").order(:id)
    @total_quantity = @quantities.values.sum
    @total_amount = @amounts.values.sum
    @low_stock_count = @low_stock_variants.size
  end
end
