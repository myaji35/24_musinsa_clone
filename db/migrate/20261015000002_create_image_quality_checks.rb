class CreateImageQualityChecks < ActiveRecord::Migration[7.2]
  def change
    create_table :image_quality_checks do |t|
      t.string :product_code, null: false
      t.text :image_url
      t.string :image_sha256
      t.string :verdict
      t.integer :score
      t.text :reason
      t.text :metrics_json
      t.string :vision_model
      t.datetime :checked_at
      t.timestamps
    end

    add_index :image_quality_checks, [ :product_code, :image_sha256 ]
  end
end
