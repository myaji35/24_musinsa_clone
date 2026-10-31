module Partner
  class DashboardController < BaseController
    def index
      @low_stock_count = Variant.joins(:product).where(products: { supplier_id: current_supplier.id }).where("variants.stock <= variants.min_stock").count
      @pending_count = current_supplier.purchase_orders.pending.count
      @open_claim_count = current_supplier.supplier_claims.where(status: "open").count
    end
  end
end
