module Partner
  class PurchaseOrdersController < BaseController
    def index
      @purchase_orders = current_supplier.purchase_orders.where.not(status: "draft").order(:expected_delivery_date, :id)
    end

    def show
      @purchase_order = visible_orders.find(params[:id])
    end

    def confirm
      @purchase_order = visible_orders.find(params[:id])
      if @purchase_order.confirm_by_supplier!
        redirect_to partner_purchase_order_path(@purchase_order), notice: "발주가 확정되었습니다."
      else
        redirect_to partner_purchase_order_path(@purchase_order), alert: "확정할 수 없는 발주입니다."
      end
    end

    private

    def visible_orders
      current_supplier.purchase_orders.where.not(status: "draft")
    end
  end
end
