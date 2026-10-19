class CreateTrendSnapshots < ActiveRecord::Migration[7.2]
  def change
    create_table :trend_snapshots do |t|
      t.string :source, null: false
      t.string :series_name, null: false
      t.date :period_start, null: false
      t.decimal :ratio, precision: 7, scale: 2, null: false
      t.integer :age_band
      t.string :gender
      t.datetime :imported_at, null: false
      t.text :note
      t.timestamps
    end
    add_index :trend_snapshots, [ :source, :series_name, :period_start, :age_band, :gender ], unique: true, name: :index_trend_snapshots_identity
    # SQLite에서 NULL을 포함한 전체 구분도 중복되지 않도록 보완한다.
    add_index :trend_snapshots, "source, series_name, period_start, COALESCE(age_band, 0), COALESCE(gender, '')",
              unique: true, name: :index_trend_snapshots_nullable_identity
  end
end
