class CreateContentUploads < ActiveRecord::Migration[8.1]
  def change
    create_table :content_uploads do |t|
      t.references :product, null: false, foreign_key: true
      t.references :character, null: false, foreign_key: true
      t.string :kind, null: false
      t.integer :slot, null: false
      t.string :sha256, null: false
      t.string :source_row
      t.timestamps
    end
    add_index :content_uploads, :sha256, unique: true
    add_index :content_uploads, [ :product_id, :character_id, :kind, :slot ], unique: true
    add_column :product_analyses, :picked_character_id, :integer
    add_column :product_analyses, :picked_at, :datetime
  end
end
