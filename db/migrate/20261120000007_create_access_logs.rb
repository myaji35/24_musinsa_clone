class CreateAccessLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :access_logs do |t|
      # 직원 계정 삭제 후에도 접속기록을 보존한다.
      t.integer :user_id, null: true
      t.string :user_label
      t.string :screen, null: false
      t.string :action, null: false
      t.string :target_type
      t.integer :target_id
      t.string :ip
      t.datetime :created_at, null: false
    end
    add_index :access_logs, :created_at
    add_index :access_logs, [ :user_id, :created_at ]
  end
end
