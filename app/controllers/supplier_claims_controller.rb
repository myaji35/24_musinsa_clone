class SupplierClaimsController < ApplicationController
  def index
    @claims = SupplierClaim.includes(:supplier).order(created_at: :desc)
  end

  def new
    @claim = SupplierClaim.new
  end

  def create
    @claim = SupplierClaim.new(params.require(:supplier_claim).permit(:supplier_id, :claim_type, :purchase_order_id, :variant_id, :quantity, :description))
    @claim.created_by_user = current_user
    if @claim.save
      redirect_to @claim, notice: "클레임이 접수되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @claim = SupplierClaim.find(params[:id])
  end

  def resolve
    @claim = SupplierClaim.find(params[:id])
    @claim.update!(status: "resolved", resolved_at: Time.current)
    redirect_to @claim, notice: "처리완료되었습니다."
  end
end
