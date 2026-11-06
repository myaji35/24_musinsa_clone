class AddProgressToKakaoExtractions < ActiveRecord::Migration[8.1]
  def change
    add_column :kakao_extractions, :progress, :string, default: "unknown", null: false
  end
end
