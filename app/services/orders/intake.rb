module Orders
  class Intake < ApplicationService
    class Result < ApplicationService::Result
      def orders
        data.fetch(:orders, [])
      end

      def checkout_number
        data[:checkout_number]
      end

      def errors
        Array(error)
      end
    end

    class InvalidInput < StandardError; end

    def initialize(items:, address:, save_consent: false, birth_year: nil, traffic_source: nil, hold_tokens: {}, user: nil)
      @hold_tokens = hold_tokens.to_h.stringify_keys
      @user = user
      @items = items
      @address = address.to_h.symbolize_keys.slice(:recipient_name, :phone, :postal_code, :address1, :address2, :country_code)
      @save_consent = ActiveModel::Type::Boolean.new.cast(save_consent) || false
      @birth_year = birth_year
      @traffic_source = traffic_source&.to_h&.symbolize_keys
    end

    def call
      raise InvalidInput, "주문할 상품을 선택해 주세요" unless @items.is_a?(Array) && @items.any?

      orders = []
      checkout_number = "CHK-#{Date.current.strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}"
      Order.transaction do |transaction|
        low_stock = false
        address = ShippingAddress.create!(@address.merge(save_consent: @save_consent, consented_at: @save_consent ? Time.current : nil))
        customer = AnonyCustomer.find_or_create_by_identifier(address.phone.gsub(/[^0-9]/, "").last(4), @birth_year)
        customer.update!(zip_prefix: address.zip_prefix)
        @items.each do |item|
          item = item.to_h.symbolize_keys
          quantity = item[:quantity].to_s
          raise InvalidInput, "수량은 1 이상의 정수여야 합니다" unless quantity.match?(/\A[0-9]+\z/) && quantity.to_i.positive?

          variant = Variant.find_by(id: item[:variant_id])
          raise InvalidInput, "선택한 상품 옵션을 찾을 수 없습니다" unless variant
          raise InvalidInput, "상품 가격이 없습니다" unless variant.product.price&.positive?

          hold = convert_hold(variant.id, quantity.to_i)
          deducted = hold ? 1 : Variant.where(id: variant.id).where("stock >= ?", quantity.to_i)
                            .update_all([ "stock = stock - ?", quantity.to_i ])
          if deducted.zero?
            remaining = variant.reload.stock.to_i
            raise InvalidInput, "재고가 부족합니다: #{variant.product.name} #{variant.color}/#{variant.size} (남은 수량 #{remaining}개)"
          end

          orders << Order.create!(user: @user, anony_customer: customer, product: variant.product, variant: variant,
                                  quantity: quantity.to_i, total_price: variant.product.price * quantity.to_i,
                                  status: "pending", shipping_address: address, checkout_number: checkout_number, **traffic_attributes)
          OrderShippingRecord.snapshot_for!(orders.last)
          if hold
            hold.update!(order: orders.last)
            surplus = hold.quantity - quantity.to_i
            if surplus.positive?
              Variant.where(id: variant.id).update_all([ "stock = COALESCE(stock, 0) + ?", surplus ])
              StockLog.create!(variant: variant, log_type: "in", quantity: surplus,
                               note: "방송 홀드 잔량 복원 #{hold.token}", skip_variant_stock_update: true)
            end
          else
            StockLog.create!(variant: variant, log_type: "out", quantity: quantity.to_i,
                             order_id: orders.last.id, note: "판매 출고 #{orders.last.order_number}",
                             skip_variant_stock_update: true)
          end
          low_stock ||= variant.reload.low_stock?
        end
        transaction.after_commit { LowStockAlertJob.perform_later } if low_stock
      end
      Result.new(success: true, data: { orders: orders, checkout_number: checkout_number })
    rescue InvalidInput => e
      Result.new(success: false, data: {}, error: [ e.message ])
    rescue ActiveRecord::RecordInvalid
      Result.new(success: false, data: {}, error: [ "배송지 또는 주문 정보가 올바르지 않습니다" ])
    end

    private

    def convert_hold(variant_id, quantity)
      token = @hold_tokens[variant_id.to_s]
      return if token.blank?

      eligible = StockHold.where(token: token, variant_id: variant_id, status: "held")
                          .where("expires_at > ?", Time.current).where("quantity >= ?", quantity)
      return if eligible.update_all(status: "converted", updated_at: Time.current).zero?

      StockHold.find_by!(token: token)
    end

    def traffic_attributes
      return {} unless @traffic_source

      {
        source_platform: @traffic_source[:platform],
        source_campaign: @traffic_source[:campaign],
        source_video_id: @traffic_source[:video_id],
        source_link_code: @traffic_source[:link_code],
        source_character_id: Character.find_by(handle: @traffic_source[:character_handle])&.id,
        source_landed_at: @traffic_source[:landed_at]
      }
    end
  end
end
