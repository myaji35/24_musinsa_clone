# 상품정보제공고시(의류) — 필수 항목이 모두 채워져야 공개할 수 있다(ISS-143). 추가 전용, 기존 상품 영향 없음.
class AddInfoNoticeToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :info_notice, :text
  end
end
