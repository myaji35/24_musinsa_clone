class CartsController < ApplicationController
  skip_before_action :require_admin

  def show
    @cart = Cart.new(session[:cart] || {})
    session[:cart] = @cart.to_h
    @suggested_products = Product.popular_picks.limit(4) if @cart.count.zero?
  end
end
