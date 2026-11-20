# Epic 8.2: 발주서 관리 컨트롤러
class PurchaseOrdersController < ApplicationController
  skip_before_action :require_admin, except: [ :destroy ]
  before_action :require_staff, except: [ :destroy, :confirm ]
  skip_before_action :verify_authenticity_token, only: [ :confirm ] # 거래처 확인 페이지는 CSRF 제외
  before_action :set_purchase_order, only: [ :show, :edit, :update, :destroy, :submit, :receive, :resend_wechat ]
  before_action :set_purchase_order_by_token, only: [ :confirm ]

  def index
    purchase_order_scope = PurchaseOrder.where(supplier_id: supplier_scope.select(:id))
    @status_filters = { "draft" => "작성 중", "submitted" => "공장 확인 대기", "receiving" => "입고 대기", "received" => "입고 완료", "cancelled" => "취소" }
    @selected_status = params[:status] if @status_filters.key?(params[:status])
    @purchase_orders = purchase_order_scope.includes(:supplier).recent
    if @selected_status
      statuses = @selected_status == "receiving" ? %w[confirmed partially_received] : @selected_status
      @purchase_orders = @purchase_orders.where(status: statuses)
    end

    @query = params[:q].to_s.strip
    if @query.present?
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
      @purchase_orders = @purchase_orders.joins(:supplier).where("purchase_orders.order_number LIKE :pattern ESCAPE '\\' OR suppliers.name LIKE :pattern ESCAPE '\\'", pattern: pattern)
    end

    contacts = WechatContact.for_account(current_account || Account.primary).includes(:wechat_messages)
    @today_tasks = [
      { name: "입금 확인 대기", count: Order.pending.count, path: admin_orders_path(status: "pending"), color: "border-l-yellow-500" },
      { name: "입고 대기 발주", count: purchase_order_scope.where(status: %w[confirmed partially_received]).count, path: purchase_orders_path(status: "receiving"), color: "border-l-blue-500" },
      { name: "공장 확인 대기", count: purchase_order_scope.where(status: "submitted").count, path: purchase_orders_path(status: "submitted"), color: "border-l-orange-500" },
      { name: "안 읽은 위챗", count: contacts.sum(&:unread_count), path: wechat_index_path, color: "border-l-green-500" },
      { name: "새 의견", count: helpers.feedback_new_count, path: feedbacks_admin_index_path, color: "border-l-purple-500" }
    ]
  end

  def show
    @purchase_order_items = @purchase_order.purchase_order_items.includes(variant: :product)
    @receipt_logs = StockLog.where(note: "발주서 입고: #{@purchase_order.order_number}", log_type: "in")
      .includes(variant: :product).order(:created_at)
  end

  def new
    @purchase_order = PurchaseOrder.new
    @purchase_order.purchase_order_items.build # 기본 1개 라인
    @suppliers = supplier_scope.active
    @variants = Variant.includes(:product).all
  end

  def create
    @purchase_order = PurchaseOrder.new(purchase_order_params)

    if supplier_in_account?(@purchase_order) && @purchase_order.save
      redirect_to @purchase_order, notice: "발주서가 생성되었습니다."
    else
      @suppliers = supplier_scope.active
      @variants = Variant.includes(:product).all
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @suppliers = supplier_scope.active
    @variants = Variant.includes(:product).all
  end

  def update
    @purchase_order.assign_attributes(purchase_order_params)
    if supplier_in_account?(@purchase_order) && @purchase_order.save
      redirect_to @purchase_order, notice: "발주서가 수정되었습니다."
    else
      @suppliers = supplier_scope.active
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
      send_confirmation_email
      Wechat::PurchaseOrderNotifier.enqueue(@purchase_order, sent_by: current_user)

      # Slack 알림 (내부 모니터링)
      begin
        Notifications::SlackNotifier.call(
          channel: "#supply-chain",
          text: "📋 발주서 제출: #{@purchase_order.order_number} - #{@purchase_order.supplier.name}"
        )
      rescue StandardError => e
        Rails.logger.error "PO submit Slack 알림 실패: #{e.message}"
      end

      redirect_to @purchase_order, notice: "발주서가 제출되었습니다. 거래처 확인 대기 중입니다."
    else
      redirect_to @purchase_order, alert: "발주서 제출에 실패했습니다. (draft 상태만 제출 가능)"
    end
  end

  def resend_wechat
    if @purchase_order.status == "submitted"
      Wechat::PurchaseOrderNotifier.enqueue(@purchase_order, sent_by: current_user)
      redirect_to @purchase_order, notice: "위챗 재발송 작업을 등록했습니다."
    else
      redirect_to @purchase_order, alert: "제출된 발주서만 재발송할 수 있습니다."
    end
  end

  # 거래처 확인 (토큰 기반 public 페이지)
  def confirm
    if @purchase_order.blank?
      render plain: "确认链接无效。 / 유효하지 않은 확인 링크입니다.", status: :not_found
      return
    end

    if request.post?
      if @purchase_order.confirm!
        render plain: "订单已确认，谢谢！ / 발주서가 확정되었습니다. 감사합니다!", status: :ok
      else
        render plain: "确认链接已处理或已过期。 / 이미 처리되었거나 만료된 확인 링크입니다.", status: :unprocessable_entity
      end
    else
      # GET 요청 시 확인 페이지 렌더링
      render :confirm, layout: false
    end
  end

  # 입고 처리
  def receive
    received_before = @purchase_order.purchase_order_items.sum(:received_quantity)
    item_ids = @purchase_order.purchase_order_items.pluck(:id).map(&:to_s)
    quantities = params[:received_quantities]&.permit(*item_ids)&.to_h
    if @purchase_order.receive!(quantities)
      items = @purchase_order.purchase_order_items
      received = items.sum(:received_quantity) - received_before
      remaining = items.sum(:quantity) - items.sum(:received_quantity)
      notice = if @purchase_order.status == "received"
        "#{received}개 입고를 기록했습니다. 발주가 입고 완료되었습니다."
      else
        "#{received}개 입고를 기록했습니다. 남은 수량 #{remaining}개는 일부 입고 상태로 남습니다."
      end
      redirect_to @purchase_order, notice: notice
    else
      redirect_to @purchase_order, alert: "입고 수량을 확인해 주세요(남은 수량을 넘을 수 없습니다)."
    end
  end

  private

  def send_confirmation_email
    if ENV["SMTP_ADDRESS"].blank?
      Rails.logger.info "PO 확인 메일 생략: SMTP_ADDRESS 미설정"
      return
    end

    NotificationMailer.purchase_order_confirmation(
      purchase_order: @purchase_order,
      supplier: @purchase_order.supplier
    ).deliver_later
  rescue StandardError
    Rails.logger.warn "PO 확인 메일 작업 등록 실패"
  end

  def set_purchase_order
    @purchase_order = PurchaseOrder.where(supplier_id: supplier_scope.select(:id)).find(params[:id])
  end

  def set_purchase_order_by_token
    @purchase_order = params[:token].blank? ? nil : PurchaseOrder.find_by(confirmation_token: params[:token])
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
