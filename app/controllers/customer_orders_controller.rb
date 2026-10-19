class CustomerOrdersController < ApplicationController
  skip_before_action :require_admin
  rate_limit to: 10, within: 10.minutes, only: :verify,
             with: -> { redirect_to orders_lookup_path, alert: "조회 시도가 너무 많습니다. 잠시 후 다시 시도해 주세요." }

  def lookup
  end

  def verify
    number = params[:checkout_number].to_s
    order = Order.includes(:anony_customer).find_by(checkout_number: number)
    suffix = params[:phone_suffix].to_s
    if order && suffix.match?(/\A[0-9]{4}\z/) && ActiveSupport::SecurityUtils.secure_compare(order.anony_customer.phone_suffix.to_s, suffix)
      session[:allowed_checkout_numbers] = (Array(session[:allowed_checkout_numbers]) + [ number ]).uniq.last(20)
      redirect_to customer_order_path(number)
    else
      @error = "주문서 번호 또는 휴대폰 뒤 4자리를 확인해 주세요"
      render :lookup, status: :unprocessable_entity
    end
  end

  def show
    unless Array(session[:allowed_checkout_numbers]).include?(params[:checkout_number])
      return redirect_to orders_lookup_path
    end

    @orders = Order.includes(:product, :variant, :shipping_address).where(checkout_number: params[:checkout_number]).order(:id)
    return redirect_to orders_lookup_path if @orders.empty?

    @address = @orders.first.shipping_address
  end
end
