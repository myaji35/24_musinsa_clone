# 리뷰 착용감(작다·딱맞다·크다) — 유니클로식 사이즈 판단 도움(추가 전용)
class AddFitToReviews < ActiveRecord::Migration[8.1]
  def change
    add_column :reviews, :fit, :string
  end
end
