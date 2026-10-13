class CreateProductAnalyses < ActiveRecord::Migration[7.2]
  def change
    create_table :product_analyses do |t|
      t.references :product, null: false, index: true, foreign_key: true
      t.string :status, default: "pending", null: false
      t.references :character, index: true, foreign_key: true
      t.integer :alt_character_id, index: true
      t.string :concept_angle
      t.string :concept_title
      t.string :hook_line
      t.string :season
      t.string :style_axis
      t.integer :target_age_band
      t.text :attributes_json
      t.text :reasoning
      t.float :confidence
      t.integer :target_units
      t.integer :target_units_override
      t.decimal :target_revenue, precision: 12, scale: 2
      t.text :assumptions_json
      t.string :model
      t.integer :input_tokens
      t.integer :output_tokens
      t.decimal :cost_usd, precision: 10, scale: 6
      t.text :error_message
      t.datetime :analyzed_at
      t.timestamps
    end
  end
end
