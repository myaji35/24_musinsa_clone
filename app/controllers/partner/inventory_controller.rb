module Partner
  class InventoryController < BaseController
    def index
      @variants = Variant.joins(:product).includes(:product).where(products: { supplier_id: current_supplier.id }).order(:id)
      @variants = @variants.where("variants.stock <= variants.min_stock") if params[:low] == "1"
    end
  end
end
