class CreateCampaigns < ActiveRecord::Migration[7.2]
  def change
    create_table :campaigns do |t|
      t.string :name, null: false # 캠페인명
      t.string :campaign_type, null: false # new_arrival, restock, personalized 등
      t.text :target_segment # JSONB: 타겟 세그먼트 조건 (예: {"age_group": "20대", "preferences": ["minimal"]})
      t.references :product, null: true, foreign_key: true # 타겟 상품 (옵션)
      t.text :message_template # Claude가 생성한 메시지 템플릿
      t.string :status, default: "draft" # draft, scheduled, sent, cancelled
      t.datetime :scheduled_at # 발송 예약 시각
      t.datetime :sent_at # 실제 발송 시각
      t.integer :target_count, default: 0 # 타겟 고객 수
      t.integer :sent_count, default: 0 # 실제 발송 수

      t.timestamps
    end

    add_index :campaigns, :campaign_type
    add_index :campaigns, :status
    add_index :campaigns, :scheduled_at
  end
end
