class CreateWechat < ActiveRecord::Migration[8.0]
  def change
    create_table :wechat_contacts do |t|
      t.references :account, null: false, foreign_key: true
      t.string :open_id, null: false
      t.string :nickname
      t.references :supplier, foreign_key: true
      t.boolean :subscribed, null: false, default: true
      t.datetime :last_inbound_at
      t.datetime :last_read_at
      t.timestamps
    end
    add_index :wechat_contacts, [:account_id, :open_id], unique: true
    create_table :wechat_messages do |t|
      t.references :account, null: false, foreign_key: true
      t.references :wechat_contact, null: false, foreign_key: true
      t.string :direction, null: false
      t.string :msg_type, null: false
      t.text :content
      t.string :media_id
      t.string :wechat_msg_id
      t.string :status, null: false
      t.text :error
      t.references :purchase_order, foreign_key: true
      t.references :sent_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :wechat_messages, :wechat_msg_id, unique: true
    add_index :wechat_messages, [:wechat_contact_id, :created_at]
  end
end
