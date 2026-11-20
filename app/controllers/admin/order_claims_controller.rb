module Admin
  class OrderClaimsController < ApplicationController
    include PersonalDataAccessLogging
    skip_before_action :require_admin
    before_action :require_staff
    before_action :set_claim, only: [ :show, :approve, :reject, :complete ]

    def index
      @status = params[:status].presence || "ongoing"
      claims = OrderClaim.all
      claims = if @status == "all"
        claims
      elsif OrderClaim::STATUSES.key?(@status)
        claims.where(status: @status)
      else
        @status = "ongoing"
        claims.where(status: %w[requested approved])
      end
      @total_count = claims.count
      @page = params[:page].to_i.clamp(1, Float::INFINITY)
      @total_pages = (@total_count / 30.0).ceil
      @claims = claims.includes(order: [ :product, :variant ]).order(created_at: :desc, id: :desc).offset((@page - 1) * 30).limit(30)
      log_personal_data_access(screen: "주문 클레임")
    end

    def show
      log_personal_data_access(screen: "주문 클레임 상세", target: @claim)
    end

    def approve
      process_claim("approve", "클레임을 승인했습니다.")
    end

    def reject
      process_claim("reject", "클레임을 거절했습니다.")
    end

    def complete
      process_claim("complete", "클레임 처리를 완료했습니다.")
    end

    private

    def set_claim
      @claim = if action_name == "show"
        OrderClaim.includes(order: [ :product, :variant ]).find(params[:id])
      else
        OrderClaim.find(params[:id])
      end
    end

    def process_claim(action, message)
      result = OrderClaims::Process.call(claim: @claim, action: action, actor: current_user, note: params[:note])
      if result.success?
        redirect_to admin_order_claim_path(@claim), notice: message
      else
        redirect_to admin_order_claim_path(@claim), alert: result.error
      end
    end
  end
end
