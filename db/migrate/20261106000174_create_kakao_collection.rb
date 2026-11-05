class CreateKakaoCollection < ActiveRecord::Migration[8.1]
  def change
    create_table :kakao_devices do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :token_digest, null: false
      t.datetime :last_seen_at, :last_collected_at, :last_error_at, :revoked_at
      t.text :last_error
      t.integer :collect_start_hour, default: 9
      t.integer :collect_end_hour, default: 19
      t.integer :max_rooms_per_run, default: 2
      t.boolean :allow_focus, default: false
      t.timestamps
    end
    add_index :kakao_devices, :token_digest, unique: true
    create_table :kakao_rooms do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :active, default: true
      t.datetime :last_collected_at
      t.integer :last_message_count, default: 0
      t.timestamps
    end
    add_index :kakao_rooms, [ :account_id, :name ], unique: true
    create_table :kakao_messages do |t|
      t.references :account, null: false, foreign_key: true
      t.references :kakao_room, null: false, foreign_key: true
      t.references :kakao_device, foreign_key: true
      t.string :author, :time_raw
      t.text :body, null: false
      t.date :sent_on
      t.datetime :sent_at
      t.string :digest, null: false
      t.timestamps
    end
    add_index :kakao_messages, [ :account_id, :digest ], unique: true
    add_index :kakao_messages, [ :kakao_room_id, :sent_at ]
  end
end
