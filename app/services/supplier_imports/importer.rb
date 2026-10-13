require "stringio"

module SupplierImports
  class Importer < ApplicationService
    def initialize(supplier_import)
      @supplier_import = supplier_import
    end

    def call
      parsed = XlsxParser.call(@supplier_import.file)
      return failure(parsed.error) if parsed.failure?

      results = parsed.data.map { |row| import_row(row) }
      @supplier_import.update!(
        total_rows: results.size,
        imported_rows: results.count { |result| result[:status] == "imported" },
        updated_rows: results.count { |result| result[:status] == "updated" },
        failed_rows: results.count { |result| result[:status] == "failed" },
        row_results: results
      )
      success(results)
    rescue StandardError => e
      failure("상품 가져오기 실패: #{e.message}")
    end

    private

    def import_row(row)
      product = nil
      status = nil
      Product.transaction do
        validate_row!(row)
        code = row[:supplier_product_code].presence
        product = Product.find_by(supplier_id: @supplier_import.supplier_id, supplier_product_code: code) if code
        status = product ? "updated" : "imported"
        product ||= Product.new
        product.assign_attributes(product_attributes(row))
        product.ai_attributes = product.parsed_ai_attributes.merge("material" => row[:material]) if row[:material].present?
        product.save!
        sync_variants(product, row)
        attach_image(product, row[:image]) if row[:image]
      end
      { row: row[:row_number], status: status, product_id: product.id, message: "상품을 #{status == 'updated' ? '갱신' : '등록'}했습니다" }
    rescue StandardError => e
      { row: row[:row_number], status: "failed", product_id: nil, message: e.message }
    end

    def validate_row!(row)
      raise "상품명이 비어 있습니다" if row[:name].blank?
      raise "판매가가 비어 있습니다" if row[:price].blank?
      raise "브랜드와 공급사가 모두 비어 있습니다" if row[:brand].blank? && @supplier_import.supplier.blank?
    end

    def product_attributes(row)
      {
        name: row[:name], supplier_product_code: row[:supplier_product_code].presence,
        supply_price: row[:supply_price].presence, price: row[:price],
        category: row[:category].presence || "미분류",
        brand: row[:brand].presence || @supplier_import.supplier.name,
        stock: row[:stock].presence, description: row[:description],
        image_url: row[:image] ? nil : row[:image_url].presence,
        supplier: @supplier_import.supplier, supplier_import: @supplier_import
      }
    end

    def sync_variants(product, row)
      colors = split_values(row[:colors], "단일")
      sizes = split_values(row[:sizes], "FREE")
      desired = colors.product(sizes)
      product.variants.where.not(id: desired.filter_map { |color, size| product.variants.find_by(color: color, size: size)&.id }).destroy_all
      desired.each do |color, size|
        product.variants.find_or_create_by!(color: color, size: size) { |variant| variant.stock = 0 }
      end
    end

    def split_values(value, fallback)
      parts = value.to_s.split(/[,·\/]/).map(&:strip).reject(&:blank?).uniq
      parts.presence || [ fallback ]
    end

    def attach_image(product, image)
      product.image.attach(io: StringIO.new(image[:io_bytes]), filename: image[:filename], content_type: image[:content_type])
    end
  end
end
