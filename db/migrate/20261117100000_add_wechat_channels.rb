class AddWechatChannels < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :wechat_channel_mode, :string, null: false, default: "manual"
    add_column :wechat_contacts, :wechat_display_name, :string
    change_column_null :wechat_contacts, :open_id, true
    add_index :wechat_contacts, [ :account_id, :wechat_display_name ], unique: true
    add_column :wechat_messages, :external_key, :string
    add_column :wechat_messages, :processed_at, :datetime
    add_column :wechat_messages, :received_at, :datetime
    add_reference :wechat_messages, :processed_by, foreign_key: { to_table: :users }
    add_index :wechat_messages, [ :account_id, :external_key ], unique: true
    create_table :wechat_agent_tokens do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :token_digest, null: false
      t.datetime :last_seen_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :wechat_agent_tokens, :token_digest, unique: true
  end
end
