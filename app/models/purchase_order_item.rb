# Epic 8.2: 발주서 품목
# 발주서의 개별 상품 라인
class PurchaseOrderItem < ApplicationRecord
  belongs_to :purchase_order
  belongs_to :variant

  # Validations
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }

  # Callbacks
  before_save :calculate_subtotal

  # Methods
  def product_name
    variant.product.name
  end

  def variant_name
    "#{variant.color} / #{variant.size}"
  end

  private

  def calculate_subtotal
    self.subtotal = quantity * unit_price
  end
end
