class CreateScheduleEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :schedule_events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :supplier, foreign_key: true
      t.string :title, null: false
      t.date :starts_on, null: false
      t.time :starts_at_time
      t.string :kind, null: false, default: "other"
      t.string :status, null: false, default: "open"
      t.text :memo
      t.references :source, polymorphic: true
      t.references :created_by_user, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :schedule_events, [ :account_id, :starts_on ]
  end
end
