class AdminOrdersController < ApplicationController
  include PersonalDataAccessLogging
  skip_before_action :require_admin
  before_action :require_staff

  def index
    @orders = Order.recent.includes(:source_character)
    @traffic_summaries = %i[platform character video].index_with { |by| Order.traffic_summary(by: by) }
    @traffic_characters = Character.where(id: @traffic_summaries[:character].map(&:first)).pluck(:id, :name).to_h
    log_personal_data_access(screen: "주문 관리")
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
