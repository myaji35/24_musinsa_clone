class NormalizeKakaoMessageExternalIds < ActiveRecord::Migration[8.1]
  def up
    create_table :kakao_message_external_ids do |t|
      t.references :account, null: false, foreign_key: true, index: false
      t.references :kakao_message, null: false, foreign_key: true
      t.string :external_id, null: false
    end
    add_index :kakao_message_external_ids, [ :account_id, :external_id ], unique: true
    add_index :kakao_messages, [ :account_id, :kakao_room_id, :match_key, :sent_at ]

    messages = Class.new(ActiveRecord::Base) { self.table_name = "kakao_messages" }
    identifiers = Class.new(ActiveRecord::Base) { self.table_name = "kakao_message_external_ids" }
    messages.find_each do |message|
      ([ message.external_id ] + Array(message.external_ids)).compact.uniq.each do |external_id|
        identifiers.create!(account_id: message.account_id, kakao_message_id: message.id, external_id: external_id)
      end
    end
    remove_column :kakao_messages, :external_ids, :json
  end

  def down
    add_column :kakao_messages, :external_ids, :json, default: []
    messages = Class.new(ActiveRecord::Base) { self.table_name = "kakao_messages" }
    identifiers = Class.new(ActiveRecord::Base) { self.table_name = "kakao_message_external_ids" }
    messages.find_each do |message|
      message.update_columns(external_ids: identifiers.where(kakao_message_id: message.id).pluck(:external_id))
    end
    remove_index :kakao_messages, [ :account_id, :kakao_room_id, :match_key, :sent_at ]
    drop_table :kakao_message_external_ids
  end
end
