class CartsController < ApplicationController
  skip_before_action :require_admin

  def show
    @cart = Cart.new(session[:cart] || {})
    session[:cart] = @cart.to_h
  end
end
