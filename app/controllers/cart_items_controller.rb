class CartItemsController < ApplicationController
  skip_before_action :require_admin

  def create
    # 공개 전(초안) 상품은 주소를 알아도 담을 수 없다
    variant = Variant.includes(:product).find_by(id: params[:variant_id])
    return head :not_found unless variant && (variant.product.published? || logged_in?)

    cart = Cart.new(session[:cart] || {})
    cart.add(params[:variant_id], params[:quantity] || 1)
    session[:cart] = cart.to_h
    if params[:buy_now] == "1"
      redirect_to new_checkout_path
    else
      redirect_to cart_path, notice: "장바구니에 담았습니다"
    end
  end

  def update
    cart = Cart.new(session[:cart] || {})
    cart.update(params[:variant_id] || params[:id], params[:quantity])
    session[:cart] = cart.to_h
    redirect_to cart_path
  end

  def destroy
    cart = Cart.new(session[:cart] || {})
    cart.remove(params[:variant_id] || params[:id])
    session[:cart] = cart.to_h
    redirect_to cart_path
  end
end
