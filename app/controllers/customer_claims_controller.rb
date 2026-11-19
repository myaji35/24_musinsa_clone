class CustomerClaimsController < ApplicationController
  skip_before_action :require_admin
  rate_limit to: 10, within: 10.minutes, only: :create,
             with: -> { redirect_to orders_lookup_path, alert: "요청이 너무 많습니다. 잠시 후 다시 시도해 주세요." }
  before_action :authorize_checkout
  before_action :set_order

  def new
    @claim = @order.order_claims.build
    render_form
  end

  def create
    attributes = params.require(:order_claim).permit(:kind, :reason_code, :detail)
    result = Orders::ClaimRequest.call(order: @order, kind: attributes[:kind],
      reason_code: attributes[:reason_code], detail: attributes[:detail], user: nil)
    if result.success?
      redirect_to customer_order_path(@order.checkout_number), notice: "요청을 접수했습니다."
    else
      @claim = @order.order_claims.build(attributes)
      @claim.errors.add(:base, result.error)
      render_form(status: :unprocessable_entity)
    end
  end

  private

  def set_order
    @order = Order.where(checkout_number: params[:checkout_number]).find(params[:order_id])
  end

  def render_form(status: :ok)
    render template: "order_claims/_form", layout: "application",
           locals: { order: @order, claim: @claim, submit_url: customer_order_claims_path(@order.checkout_number, order_id: @order.id),
                     back_url: customer_order_path(@order.checkout_number) }, status: status
  end

  def authorize_checkout
    unless Array(session[:allowed_checkout_numbers]).include?(params[:checkout_number])
      redirect_to orders_lookup_path
    end
  end
end
