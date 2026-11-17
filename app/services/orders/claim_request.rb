module Orders
  class ClaimRequest < ApplicationService
    def initialize(order:, kind:, reason_code:, detail:, user: nil)
      @order, @kind, @reason_code, @detail, @user = order, kind, reason_code, detail, user
    end

    def call
      claim = nil
      @order.with_lock do
        return failure("지금은 이 요청을 할 수 없습니다.") unless @order.claimable_kinds.include?(@kind)

        claim = @order.order_claims.build(kind: @kind, reason_code: @reason_code, detail: @detail,
                                         user: @user, requester: @user ? "member" : "guest")
        claim.validate!
        if @kind == "cancel" && @order.status == "pending"
          raise "지금은 이 요청을 할 수 없습니다." unless @order.cancel!

          claim.assign_attributes(status: "completed", processed_at: Time.current)
        end
        claim.save!
      end
      success(claim)
    rescue ActiveRecord::RecordInvalid => error
      failure(error.record.errors.full_messages.join(" "))
    rescue StandardError => error
      failure(error.message)
    end
  end
end
