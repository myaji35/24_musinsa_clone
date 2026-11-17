class MyController < ApplicationController
  skip_before_action :require_admin
  before_action :require_login

  def show
  end

  def orders
    @orders = current_user.orders.includes(:product, :variant).order(created_at: :desc)
  end
end
