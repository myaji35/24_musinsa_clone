class ContentUpload < ApplicationRecord
  belongs_to :product
  belongs_to :character
  has_one_attached :file

  validates :kind, inclusion: { in: %w[cut] }
  validates :slot, inclusion: { in: 1..3 }
  validates :sha256, presence: true, uniqueness: true
  validate :validate_file

  private

  def validate_file
    unless file.attached?
      errors.add(:file, "파일이 필요합니다")
      return
    end
    errors.add(:file, "는 PNG, JPEG, WebP만 가능합니다") unless file.content_type.in?(%w[image/png image/jpeg image/webp])
    errors.add(:file, "는 10MB 이하여야 합니다") if file.byte_size > 10.megabytes
  end
end
