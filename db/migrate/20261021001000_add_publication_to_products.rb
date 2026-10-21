# 상세페이지 컨펌 후 공개(ISS-141). 기존 상품은 이미 손님에게 보이고 있으므로 published 로 유지한다(운영 영향 없음, 추가 전용).
class AddPublicationToProducts < ActiveRecord::Migration[8.1]
  def up
    add_column :products, :status, :string, null: false, default: "published"
    add_column :products, :published_at, :datetime
    add_column :products, :published_by_id, :integer
    add_index :products, :status
    execute "UPDATE products SET published_at = created_at"
  end

  def down
    remove_index :products, :status
    remove_column :products, :published_by_id
    remove_column :products, :published_at
    remove_column :products, :status
  end
end
