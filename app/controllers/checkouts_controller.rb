class CheckoutsController < ApplicationController
  skip_before_action :require_admin
  before_action :load_cart

  def new
    @checkout = {}
  end

  def create
    @checkout = params.require(:checkout).permit(:recipient_name, :phone, :postal_code, :address1, :address2, :birth_year, :privacy_consent).to_h
    unless @checkout["privacy_consent"] == "1"
      @errors = [ "개인정보 수집·이용에 동의해 주세요" ]
      return render :new, status: :unprocessable_entity
    end

    result = Orders::Intake.call(
      items: @cart.items.map { |item| { variant_id: item.variant.id, quantity: item.quantity } },
      address: @checkout.slice("recipient_name", "phone", "postal_code", "address1", "address2"),
      birth_year: @checkout["birth_year"].presence, save_consent: false
    )
    if result.success?
      session[:cart] = {}
      session[:allowed_checkout_numbers] = (Array(session[:allowed_checkout_numbers]) + [ result.checkout_number ]).last(20)
      redirect_to customer_order_path(result.checkout_number)
    else
      @errors = result.errors
      render :new, status: :unprocessable_entity
    end
  end

  private

  def load_cart
    @cart = Cart.new(session[:cart] || {})
    redirect_to cart_path, alert: "장바구니가 비어 있습니다" if @cart.count.zero?
  end
end
