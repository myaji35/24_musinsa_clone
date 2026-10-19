class ShippingAddressPurgeJob < ApplicationJob
  queue_as :default

  def perform
    count = 0
    ShippingAddress.purgeable.find_each do |address|
      address.destroy!
      count += 1
    end
    Rails.logger.info("배송지 파기 완료: #{count}건")
    count
  end
end
