class CreateFeedbacks < ActiveRecord::Migration[8.1]
  def change
    create_table :feedbacks do |t|
      t.string :kind, default: "other", null: false
      t.text :body, null: false
      t.string :source, default: "customer_web", null: false
      t.string :status, default: "new", null: false
      t.string :page_url, limit: 500
      t.references :product, foreign_key: { on_delete: :nullify }
      t.text :contact_email
      t.boolean :contact_consent, default: false, null: false
      t.datetime :contact_purged_at
      t.datetime :answered_at
      t.string :reporter_hash, index: true
      t.timestamps
    end
    add_index :feedbacks, :status
    add_index :feedbacks, :kind
    add_index :feedbacks, :created_at
  end
end
