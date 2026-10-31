module Partner
  class ClaimsController < BaseController
    def index
      @claims = current_supplier.supplier_claims.order(created_at: :desc)
      @claims = @claims.where(status: params[:status]) if SupplierClaim::STATUSES.key?(params[:status])
    end

    def show
      @claim = current_supplier.supplier_claims.find(params[:id])
    end

    def update
      @claim = current_supplier.supplier_claims.find(params[:id])
      @claim.with_lock do
        if @claim.status == "resolved"
          return redirect_to partner_claim_path(@claim), alert: "처리완료된 클레임은 답변할 수 없습니다."
        end
        response = params.require(:supplier_claim).permit(:supplier_response)[:supplier_response]
        if response.blank?
          @claim.errors.add(:supplier_response, "답변을 입력해 주세요.")
          return render :show, status: :unprocessable_entity
        end
        @claim.update!(supplier_response: response, status: "answered", responded_at: Time.current)
      end
      redirect_to partner_claim_path(@claim), notice: "답변이 등록되었습니다."
    end
  end
end
