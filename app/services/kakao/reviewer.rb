module Kakao
  class Reviewer < ApplicationService
    def initialize(extraction, user:, attributes: {}, target: "record")
      @extraction, @user, @attributes, @target = extraction, user, attributes, target
    end

    def call
      @extraction.with_lock do
        raise ArgumentError, "이미 검토된 항목입니다" unless @extraction.status == "pending"

        @extraction.assign_attributes(@attributes)
        @extraction.save!
        common = { account: @extraction.account, supplier: @extraction.supplier, source: @extraction, created_by_user: @user }
        applied = case @target
        when "schedule"
          ScheduleEvent.create!(common.merge(title: @extraction.summary, starts_on: @extraction.date,
            kind: { "schedule" => "meeting", "order" => "delivery" }.fetch(@extraction.kind, @extraction.kind), memo: @extraction.time_text))
        when "sale", "purchase", "receipt", "payment"
          raise ArgumentError, "거래처를 선택해 주세요" unless @extraction.supplier
          raise ArgumentError, "금액을 입력해 주세요" unless @extraction.amount

          LedgerEntry.create!(common.merge(entry_type: @target, occurred_on: @extraction.date, amount: @extraction.amount,
            quantity: @extraction.quantity, unit: @extraction.unit, item_name: @extraction.product_hint, memo: @extraction.summary))
        when "record" then nil
        else raise ArgumentError, "반영 대상이 유효하지 않습니다"
        end
        @extraction.update!(status: "approved", applied: applied, reviewed_by_user: @user, reviewed_at: Time.current)
      end
      success(@extraction)
    rescue ActiveRecord::RecordInvalid, ArgumentError => error
      failure(error.message)
    end
  end
end
