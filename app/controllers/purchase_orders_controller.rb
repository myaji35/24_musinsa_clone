# Epic 8.2: 발주서 관리 컨트롤러
class PurchaseOrdersController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :confirm ] # 거래처 확인 페이지는 CSRF 제외
  before_action :set_purchase_order, only: [ :show, :edit, :update, :destroy, :submit, :receive ]
  before_action :set_purchase_order_by_token, only: [ :confirm ]

  def index
    @purchase_orders = PurchaseOrder.includes(:supplier).recent
  end

  def show
    @purchase_order_items = @purchase_order.purchase_order_items.includes(variant: :product)
  end

  def new
    @purchase_order = PurchaseOrder.new
    @purchase_order.purchase_order_items.build # 기본 1개 라인
    @suppliers = Supplier.active
    @variants = Variant.includes(:product).all
  end

  def create
    @purchase_order = PurchaseOrder.new(purchase_order_params)

    if @purchase_order.save
      redirect_to @purchase_order, notice: "발주서가 생성되었습니다."
    else
      @suppliers = Supplier.active
      @variants = Variant.includes(:product).all
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @suppliers = Supplier.active
    @variants = Variant.includes(:product).all
  end

  def update
    if @purchase_order.update(purchase_order_params)
      redirect_to @purchase_order, notice: "발주서가 수정되었습니다."
    else
      @suppliers = Supplier.active
      @variants = Variant.includes(:product).all
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @purchase_order.update(status: "cancelled")
    redirect_to purchase_orders_path, notice: "발주서가 취소되었습니다."
  end

  # 발주서 제출 (거래처에게 발송)
  def submit
    if @purchase_order.submit!
      # 거래처에게 확인 이메일 발송
      NotificationMailer.purchase_order_confirmation(
        purchase_order: @purchase_order,
        supplier: @purchase_order.supplier
      ).deliver_later

      # Slack 알림 (내부 모니터링)
      Notifications::SlackNotifier.call(
        channel: "#supply-chain",
        text: "📋 발주서 제출: #{@purchase_order.order_number} - #{@purchase_order.supplier.name}"
      )

      redirect_to @purchase_order, notice: "발주서가 제출되었습니다. 거래처 확인 대기 중입니다."
    else
      redirect_to @purchase_order, alert: "발주서 제출에 실패했습니다. (draft 상태만 제출 가능)"
    end
  end

  # 거래처 확인 (토큰 기반 public 페이지)
  def confirm
    if @purchase_order.blank?
      render plain: "유효하지 않은 확인 링크입니다.", status: :not_found
      return
    end

    if request.post?
      if @purchase_order.confirm!
        render plain: "발주서가 확정되었습니다. 감사합니다!", status: :ok
      else
        render plain: "발주서 확정에 실패했습니다.", status: :unprocessable_entity
      end
    else
      # GET 요청 시 확인 페이지 렌더링
      render :confirm, layout: false
    end
  end

  # 입고 처리
  def receive
    if @purchase_order.receive!
      redirect_to @purchase_order, notice: "입고 처리가 완료되었습니다. 재고가 업데이트되었습니다."
    else
      redirect_to @purchase_order, alert: "입고 처리에 실패했습니다. (confirmed 상태만 처리 가능)"
    end
  end

  private

  def set_purchase_order
    @purchase_order = PurchaseOrder.find(params[:id])
  end

  def set_purchase_order_by_token
    @purchase_order = PurchaseOrder.find_by(confirmation_token: params[:token])
  end

  def purchase_order_params
    params.require(:purchase_order).permit(
      :supplier_id,
      :expected_delivery_date,
      :notes,
      purchase_order_items_attributes: [
        :id,
        :variant_id,
        :quantity,
        :unit_price,
        :_destroy
      ]
    )
  end
end
