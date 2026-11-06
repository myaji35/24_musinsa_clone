class AdminOrdersController < ApplicationController
  def index
    @orders = Order.recent
  end

  def confirm_payment
    order = Order.find(params[:id])
    order.with_lock do
      unless order.status == "pending"
        redirect_to admin_orders_path, alert: "입금 대기 주문만 확인할 수 있습니다."
        return
      end
      order.update!(status: "paid")
    end
    redirect_to admin_orders_path, notice: "입금을 확인하여 결제 완료 처리했습니다."
  end
end
