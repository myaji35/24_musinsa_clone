class BackfillNullVariantStock < ActiveRecord::Migration[7.2]
  def up
    Variant.where(stock: nil).update_all(stock: 0)
  end

  def down
    # 기존 nil 재고와 원래 0인 재고를 구분할 수 없어 되돌리지 않음
    raise ActiveRecord::IrreversibleMigration
  end
end
