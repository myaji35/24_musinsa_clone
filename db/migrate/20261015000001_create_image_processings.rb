class CreateImageProcessings < ActiveRecord::Migration[7.2]
  def change
    create_table :image_processings do |t|
      t.references :product, null: false, index: false, foreign_key: true
      t.string :kind, null: false
      t.string :status, null: false, default: "pending"
      t.string :provider
      t.integer :cost_cents, null: false, default: 0
      t.text :error_message
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    add_index :image_processings, [ :product_id, :kind ]
    add_index :image_processings, :status
    add_index :image_processings, :created_at
  end
end
