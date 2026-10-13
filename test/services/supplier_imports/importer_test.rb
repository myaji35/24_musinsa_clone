require "test_helper"

class SupplierImports::ImporterTest < ActiveSupport::TestCase
  def setup
    @import = SupplierImport.create!(supplier: suppliers(:one), file: { io: File.open(Rails.root.join("test/fixtures/files/supplier_sample.xlsx")), filename: "supplier_sample.xlsx", content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" })
  end

  test "세 상품을 만들고 판매가 없는 행만 실패한다" do
    assert_difference "Product.count", 3 do
      result = SupplierImports::Importer.call(@import)
      assert result.success?, result.error
    end
    @import.reload
    assert_equal [ 4, 3, 0, 1 ], [ @import.total_rows, @import.imported_rows, @import.updated_rows, @import.failed_rows ]
    assert_includes @import.row_results.last["message"], "판매가"
    product = Product.find_by!(supplier_product_code: "SUP-001")
    assert product.image.attached?
    assert_equal 4, product.variants.count
    assert_equal 15, product.stock
    assert_equal "면", product.parsed_ai_attributes["material"]
    assert_equal suppliers(:one).name, product.brand
  end

  test "재가져오기는 상품을 갱신하고 중복 생성하지 않는다" do
    SupplierImports::Importer.call(@import)
    assert_no_difference "Product.count" do
      result = SupplierImports::Importer.call(@import)
      assert result.success?, result.error
    end
    assert_equal 3, @import.reload.updated_rows
    assert_equal 0, @import.imported_rows
  end
end
