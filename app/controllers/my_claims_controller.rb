class MyClaimsController < ApplicationController
  skip_before_action :require_admin
  before_action :require_login
  before_action :set_order

  def new
    @claim = @order.order_claims.build
    render_form
  end

  def create
    attributes = params.require(:order_claim).permit(:kind, :reason_code, :detail)
    result = Orders::ClaimRequest.call(order: @order, kind: attributes[:kind],
      reason_code: attributes[:reason_code], detail: attributes[:detail], user: current_user)
    if result.success?
      redirect_to my_orders_path, notice: "요청을 접수했습니다."
    else
      @claim = @order.order_claims.build(attributes)
      @claim.errors.add(:base, result.error)
      render_form(status: :unprocessable_entity)
    end
  end

  private

  def set_order
    @order = current_user.orders.find(params[:id])
  end

  def render_form(status: :ok)
    render template: "order_claims/_form", layout: "application",
           locals: { order: @order, claim: @claim, submit_url: my_order_claims_path(@order) }, status: status
  end
end
