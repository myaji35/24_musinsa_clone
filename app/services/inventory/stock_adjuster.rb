# Service for adjusting stock levels (입출고 처리)
module Inventory
  class StockAdjuster < ApplicationService
    attr_reader :variant, :quantity, :stock_type, :note, :user_name

    def initialize(barcode:, quantity:, stock_type:, note: nil, user_name: "System")
      @barcode = barcode
      @quantity = quantity.to_i
      @stock_type = stock_type # "in" or "out"
      @note = note
      @user_name = user_name
    end

    def call
      @variant = find_variant
      return failure("바코드를 찾을 수 없습니다: #{@barcode}") unless @variant

      return failure("수량은 양수여야 합니다") if @quantity <= 0

      ActiveRecord::Base.transaction do
        adjust_stock
        create_stock_log
        check_low_stock_alert
      end

      success({
        variant: @variant,
        new_stock: @variant.stock,
        message: stock_message
      })
    rescue StandardError => e
      Rails.logger.error "StockAdjuster Error: #{e.message}"
      failure("재고 조정 실패: #{e.message}")
    end

    private

    def find_variant
      Variant.find_by(barcode: @barcode)
    end

    def adjust_stock
      case @stock_type
      when "in"
        @variant.increment!(:stock, @quantity)
      when "out"
        if @variant.stock < @quantity
          raise "재고 부족: 현재 #{@variant.stock}개, 요청 #{@quantity}개"
        end
        @variant.decrement!(:stock, @quantity)
      else
        raise "잘못된 stock_type: #{@stock_type}"
      end
    end

    def create_stock_log
      StockLog.create!(
        variant: @variant,
        stock_type: @stock_type,
        quantity: @quantity,
        note: @note,
        user_name: @user_name
      )
    end

    def check_low_stock_alert
      if @variant.low_stock?
        LowStockAlertJob.perform_later(@variant.id)
      end
    end

    def stock_message
      case @stock_type
      when "in"
        "입고 완료: #{@quantity}개 추가 (현재 재고: #{@variant.stock}개)"
      when "out"
        "출고 완료: #{@quantity}개 차감 (현재 재고: #{@variant.stock}개)"
      end
    end
  end
end
