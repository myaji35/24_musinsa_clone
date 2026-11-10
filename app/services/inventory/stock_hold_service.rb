module Inventory
  class StockHoldService < ApplicationService
    def self.reserve(**attributes)
      new.reserve(**attributes)
    end

    def self.release(token)
      new.release(token)
    end

    def self.release_expired
      new.release_expired
    end

    def reserve(variant_id:, quantity:, source: nil, ttl: 10.minutes)
      return failure("수량은 1 이상의 정수여야 합니다") unless quantity.to_s.match?(/\A[0-9]+\z/) && quantity.to_i.positive?

      quantity = quantity.to_i
      StockHold.transaction do
        deducted = Variant.where(id: variant_id).where("stock >= ?", quantity)
                          .update_all([ "stock = stock - ?", quantity ])
        return failure("재고가 부족합니다: 옵션 #{variant_id}") if deducted.zero?

        hold = StockHold.create!(variant_id: variant_id, quantity: quantity, source: source,
                                 token: SecureRandom.uuid, expires_at: Time.current + ttl)
        StockLog.create!(variant_id: variant_id, quantity: quantity, log_type: "out",
                         note: "방송 홀드 #{hold.token}", skip_variant_stock_update: true)
        success(hold)
      end
    rescue ActiveRecord::RecordInvalid => e
      failure("홀드 정보가 올바르지 않습니다: #{e.record.errors.full_messages.join(', ')}")
    end

    def release(token)
      StockHold.transaction do
        changed = StockHold.where(token: token, status: "held")
                           .update_all(status: "released", updated_at: Time.current)
        return success(false) if changed.zero?

        hold = StockHold.find_by!(token: token)
        Variant.where(id: hold.variant_id).update_all([ "stock = COALESCE(stock, 0) + ?", hold.quantity ])
        StockLog.create!(variant_id: hold.variant_id, quantity: hold.quantity, log_type: "in",
                         note: "방송 홀드 해제 #{hold.token}", skip_variant_stock_update: true)
        success(true)
      end
    end

    def release_expired
      count = 0
      StockHold.expired.find_each do |hold|
        result = release(hold.token)
        count += 1 if result.success? && result.data
      end
      success(count)
    end
  end
end
