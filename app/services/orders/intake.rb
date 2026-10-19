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

    def initialize(items:, address:, save_consent: false, birth_year: nil)
      @items = items
      @address = address.to_h.symbolize_keys.slice(:recipient_name, :phone, :postal_code, :address1, :address2, :country_code)
      @save_consent = ActiveModel::Type::Boolean.new.cast(save_consent) || false
      @birth_year = birth_year
    end

    def call
      raise InvalidInput, "주문할 상품을 선택해 주세요" unless @items.is_a?(Array) && @items.any?

      orders = []
      checkout_number = "CHK-#{Date.current.strftime('%Y%m%d')}-#{SecureRandom.hex(4).upcase}"
      Order.transaction do
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

          orders << Order.create!(anony_customer: customer, product: variant.product, variant: variant,
                                  quantity: quantity.to_i, total_price: variant.product.price * quantity.to_i,
                                  status: "pending", shipping_address: address, checkout_number: checkout_number)
        end
      end
      Result.new(success: true, data: { orders: orders, checkout_number: checkout_number })
    rescue InvalidInput => e
      Result.new(success: false, data: {}, error: [ e.message ])
    rescue ActiveRecord::RecordInvalid
      Result.new(success: false, data: {}, error: [ "배송지 또는 주문 정보가 올바르지 않습니다" ])
    end
  end
end
