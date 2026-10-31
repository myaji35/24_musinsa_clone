class SupplierClaim < ApplicationRecord
  TYPES = { "defective" => "불량", "wrong_item" => "오배송", "short_quantity" => "수량부족", "other" => "기타" }.freeze
  STATUSES = { "open" => "접수", "answered" => "답변완료", "resolved" => "처리완료" }.freeze

  belongs_to :supplier
  belongs_to :purchase_order, optional: true
  belongs_to :variant, optional: true
  belongs_to :created_by_user, class_name: "User", optional: true
  validates :description, presence: true
  validates :claim_type, inclusion: { in: TYPES.keys }
  validates :status, inclusion: { in: STATUSES.keys }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :same_supplier

  private

  def same_supplier
    if purchase_order && purchase_order.supplier_id != supplier_id
      errors.add(:purchase_order, "는 같은 거래처 소속이어야 합니다.")
    end
    if variant && variant.product.supplier_id != supplier_id
      errors.add(:variant, "는 같은 거래처 소속이어야 합니다.")
    end
  end
end
