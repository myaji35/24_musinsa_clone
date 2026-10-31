class OrderShippingRecord < ApplicationRecord
  belongs_to :order

  encrypts :recipient_name, :phone, :postal_code, :address1, :address2

  scope :expired, -> { where("retain_until <= ?", Time.current) }

  def self.snapshot_for!(order)
    order.with_lock do
      existing = find_by(order: order)
      return existing if existing

      address = order.shipping_address
      return unless address

      create!(address.attributes.slice("recipient_name", "phone", "postal_code", "address1", "address2", "country_code")
                     .merge(order: order, retain_until: order.created_at + Rails.configuration.x.order_record_retention_years.years))
    end
  end
end
