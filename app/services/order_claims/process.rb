module OrderClaims
  class Process < ApplicationService
    def initialize(claim:, action:, actor:, note: nil)
      @claim, @action, @actor, @note = claim, action, actor, note
    end

    def call
      @claim.with_lock do
        expected_status = { "approve" => "requested", "reject" => "requested", "complete" => "approved" }[@action]
        return failure("지금은 이 요청을 처리할 수 없습니다.") unless expected_status && @claim.status == expected_status
        return failure("거절 사유를 입력해 주세요.") if @action == "reject" && @note.blank?

        now = Time.current
        case @action
        when "approve"
          if @claim.kind == "cancel" && !@claim.order.cancel!
            return failure("이미 배송된 주문은 취소할 수 없습니다.")
          end
          @claim.status = "approved"
        when "reject"
          @claim.status = "rejected"
        when "complete"
          @claim.order.with_lock { @claim.order.update!(status: "returned") } if @claim.kind == "return"
          @claim.refunded_at = now if @claim.kind.in?(%w[cancel return])
          @claim.status = "completed"
        end
        @claim.processed_by = @actor
        @claim.processed_at = now
        @claim.admin_note = [ @claim.admin_note.presence, @note.presence ].compact.join("\n") if @note.present?
        @claim.save!
      end
      success(@claim)
    rescue StandardError => error
      failure(error.message)
    end
  end
end
