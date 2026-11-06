class CreateKakaoExtractions < ActiveRecord::Migration[8.1]
  def change
    add_reference :kakao_rooms, :supplier, foreign_key: true
    add_column :kakao_rooms, :extraction_scheduled_at, :datetime
    add_column :kakao_rooms, :last_extraction_error, :text
    add_column :kakao_messages, :extraction_gap, :boolean, default: false, null: false
    create_table :kakao_extractions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :kakao_room, null: false, foreign_key: true
      t.references :supplier, foreign_key: true
      t.string :kind, null: false
      t.text :summary, null: false
      t.date :date
      t.string :time_text
      t.integer :quantity
      t.string :unit
      t.decimal :amount, precision: 12, scale: 2
      t.string :product_hint
      t.string :counterparty_hint
      t.decimal :confidence
      t.string :status, default: "pending", null: false
      t.references :applied, polymorphic: true
      t.references :reviewed_by_user, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.string :model_name
      t.boolean :source_changed, default: false, null: false
      t.timestamps
    end
    create_table :kakao_extraction_messages do |t|
      t.references :account, null: false, foreign_key: true
      t.references :kakao_extraction, null: false, foreign_key: true
      t.references :kakao_message, null: false, foreign_key: true
      t.index [ :kakao_extraction_id, :kakao_message_id ], unique: true, name: "idx_kakao_extraction_evidence"
    end
  end
end
