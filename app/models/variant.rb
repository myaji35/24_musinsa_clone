class Variant < ApplicationRecord
  belongs_to :product
  has_many :stock_logs, dependent: :destroy
  has_many :orders
  has_many :notifications, dependent: :destroy # Epic 5.1

  # 유효성 검증
  validates :color, presence: true
  validates :size, presence: true
  validates :stock, numericality: { greater_than_or_equal_to: 0 }, allow_nil: false
  validates :min_stock, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :barcode, uniqueness: true, allow_blank: true

  # 생성 시 재고 기본값 설정
  before_validation :set_default_stock, on: :create

  # 바코드 자동 생성 (Story 1.3 Acceptance Criteria)
  # 형식: {PRODUCT_ID}-{COLOR}-{SIZE}
  before_validation :generate_barcode, on: :create

  # 재고 부족 체크
  def low_stock?
    min_stock.present? && stock.present? && stock <= min_stock
  end

  # 품절 체크
  def out_of_stock?
    stock.nil? || stock <= 0
  end

  private

  def set_default_stock
    self.stock ||= 0
  end

  def generate_barcode
    return if barcode.present?

    if product_id.present? && color.present? && size.present?
      # 바코드 형식: PRODUCT_ID-COLOR-SIZE
      # 예: 1-black-M
      base_barcode = "#{product_id}-#{color.parameterize}-#{size.upcase}"

      # 중복 방지: 동일한 바코드가 있으면 번호 추가
      counter = 1
      generated_barcode = base_barcode

      while Variant.exists?(barcode: generated_barcode)
        generated_barcode = "#{base_barcode}-#{counter}"
        counter += 1
      end

      self.barcode = generated_barcode
      self.sku_code ||= generated_barcode # SKU 코드도 자동 생성
    end
  end
end
