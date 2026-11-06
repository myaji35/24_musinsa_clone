class UpgradeKakaoBridgeProtocol < ActiveRecord::Migration[8.1]
  def change
    change_table :kakao_devices do |t|
      t.remove :collect_start_hour, :collect_end_hour, :max_rooms_per_run, type: :integer
      t.remove :allow_focus, type: :boolean
      t.boolean :realtime_enabled, default: true
      t.boolean :backfill_enabled, default: true
      t.string :backfill_window, default: "03:00-05:00"
      t.string :time_zone, default: "Asia/Seoul"
      t.integer :backfill_max_rooms, default: 5
      t.integer :backfill_limit_per_room, default: 100
      t.boolean :open_window_enabled, default: false
      t.integer :open_window_poll_seconds, default: 300
      t.string :agent_version
      t.json :permissions, default: {}
      t.boolean :ok
      t.datetime :last_realtime_at, :last_backfill_at
    end
    add_column :kakao_rooms, :aliases, :text
    change_table :kakao_messages do |t|
      t.string :source, :sources, :external_id, :time_precision, :match_key
      t.boolean :truncated, default: false
      t.boolean :is_mine, default: false
      t.json :external_ids, default: []
      t.boolean :needs_extraction, default: true
    end
    change_column_null :kakao_messages, :digest, true
    remove_index :kakao_messages, [ :account_id, :digest ]
    add_index :kakao_messages, [ :account_id, :external_id ], unique: true
  end
end
