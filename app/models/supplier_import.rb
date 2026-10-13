class SupplierImport < ApplicationRecord
  belongs_to :supplier, optional: true
  has_one_attached :file
  has_many :products

  serialize :row_results, coder: JSON

  validates :status, inclusion: { in: %w[pending processing done failed] }
  validate :xlsx_file

  private

  def xlsx_file
    if !file.attached?
      errors.add(:file, "을 첨부해 주세요")
    elsif File.extname(file.filename.to_s).downcase != ".xlsx"
      errors.add(:file, "은 .xlsx 파일만 업로드할 수 있습니다")
    end
  end
end
