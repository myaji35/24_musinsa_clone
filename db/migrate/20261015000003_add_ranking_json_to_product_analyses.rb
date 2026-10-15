class AddRankingJsonToProductAnalyses < ActiveRecord::Migration[7.2]
  def change
    add_column :product_analyses, :ranking_json, :text
  end
end
