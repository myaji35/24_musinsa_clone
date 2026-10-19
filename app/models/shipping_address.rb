class ShippingAddress < ApplicationRecord
  has_many :orders, dependent: :nullify

  validates :recipient_name, :phone, :postal_code, :address1, :country_code,
            presence: { message: "필수 입력 항목입니다" }
  validates :postal_code, format: { with: /\A[0-9]{5}\z/, message: "국내 우편번호는 숫자 5자리여야 합니다" }, if: -> { country_code == "KR" }
  validates :phone, format: { with: /\A[0-9-]{9,15}\z/, message: "전화번호는 숫자와 하이픈 9~15자로 입력해 주세요" }

  scope :purgeable, -> { where(save_consent: false).where("purge_after <= ?", Time.current) }

  def zip_prefix
    postal_code.to_s.first(3)
  end

  def schedule_purge!(from: Time.current)
    return if save_consent?

    update!(purge_after: from + Rails.configuration.x.shipping_address_retention_days.days)
  end

  def revoke_consent!
    update!(save_consent: false, consented_at: nil, purge_after: Time.current)
  end
end
