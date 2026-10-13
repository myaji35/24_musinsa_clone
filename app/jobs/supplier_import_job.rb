class SupplierImportJob < ApplicationJob
  queue_as :default

  def perform(import_id)
    supplier_import = SupplierImport.find(import_id)
    supplier_import.update!(status: "processing")
    result = SupplierImports::Importer.call(supplier_import)
    if result.success?
      supplier_import.update!(status: "done")
    else
      raise result.error
    end
  rescue StandardError => e
    Rails.logger.error "상품 입고 실패 (#{import_id}): #{e.message}"
    supplier_import&.update_columns(status: "failed", error_message: e.message, updated_at: Time.current)
  end
end
