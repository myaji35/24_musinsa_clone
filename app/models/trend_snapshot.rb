class TrendSnapshot < ApplicationRecord
  validates :source, inclusion: { in: %w[datalab_csv datalab_api] }
  validates :series_name, :period_start, :imported_at, presence: true
  validates :ratio, numericality: { in: 0..100 }
  validates :age_band, inclusion: { in: [ 20, 30, 40, 50 ] }, allow_nil: true

  def self.store!(attributes)
    identity = attributes.slice(:source, :series_name, :period_start, :age_band, :gender)
    snapshot = find_or_initialize_by(identity)
    created = snapshot.new_record?
    snapshot.update!(attributes)
    created
  end
end
