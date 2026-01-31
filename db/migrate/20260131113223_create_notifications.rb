class CreateNotifications < ActiveRecord::Migration[7.2]
  def change
    create_table :notifications do |t|
      t.references :variant, null: false, foreign_key: true
      t.string :notification_type, null: false # low_stock, restock_needed 등
      t.text :message # Claude가 생성한 메시지
      t.string :status, default: "pending" # pending, sent, failed
      t.datetime :sent_at # 실제 발송 시각

      t.timestamps
    end

    add_index :notifications, :notification_type
    add_index :notifications, :status
    add_index :notifications, :sent_at
  end
end
