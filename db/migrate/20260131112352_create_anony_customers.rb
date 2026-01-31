class CreateAnonyCustomers < ActiveRecord::Migration[7.2]
  def change
    create_table :anony_customers do |t|
      t.string :uuid, null: false # 익명 식별자 (SecureRandom.uuid)
      t.string :zip_prefix, limit: 3 # 우편번호 앞 3자리
      t.string :phone_suffix, limit: 4 # 전화번호 뒤 4자리
      t.integer :birth_year # 생년
      t.text :preference_tags # JSONB: 취향 태그 {"minimal": 3, "casual": 5}

      t.timestamps
    end

    add_index :anony_customers, :uuid, unique: true
    add_index :anony_customers, [:phone_suffix, :birth_year] # 중복 방지용
    add_index :anony_customers, :zip_prefix # 지역 분석용
  end
end
