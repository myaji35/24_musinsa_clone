# Service for scanning barcodes and finding variants
module Inventory
  class BarcodeScanner < ApplicationService
    attr_reader :barcode

    def initialize(barcode:)
      @barcode = barcode&.strip
    end

    def call
      return failure("바코드가 비어있습니다") if @barcode.blank?

      variant = Variant.includes(:product).find_by(barcode: @barcode)
      return failure("바코드를 찾을 수 없습니다: #{@barcode}") unless variant

      success({
        variant: variant,
        product: variant.product,
        stock_info: stock_info(variant),
        alerts: generate_alerts(variant)
      })
    rescue StandardError => e
      Rails.logger.error "BarcodeScanner Error: #{e.message}"
      failure("바코드 스캔 실패: #{e.message}")
    end

    private

    def stock_info(variant)
      {
        current_stock: variant.stock || 0,
        min_stock: variant.min_stock || 0,
        is_low_stock: variant.low_stock?,
        is_out_of_stock: variant.out_of_stock?,
        status: stock_status(variant)
      }
    end

    def stock_status(variant)
      if variant.out_of_stock?
        "품절"
      elsif variant.low_stock?
        "재고 부족"
      else
        "정상"
      end
    end

    def generate_alerts(variant)
      alerts = []
      alerts << { type: "warning", message: "재고 부족 (#{variant.stock}개)" } if variant.low_stock?
      alerts << { type: "danger", message: "품절" } if variant.out_of_stock?
      alerts
    end
  end
end
