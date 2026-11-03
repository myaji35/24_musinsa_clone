class ShippingAddressPurgeJob < ApplicationJob
  queue_as :default

  def perform
    count = 0
    ShippingAddress.purgeable.find_each do |address|
      begin
        address.with_lock do
          address.orders.find_each { |order| OrderShippingRecord.snapshot_for!(order) }
          address.destroy!
        end
        count += 1
      rescue StandardError => e
        Rails.logger.error("배송지 파기 실패: 배송지 ID=#{address.id}, 오류=#{e.class}")
      end
    end
    Rails.logger.info("배송지 파기 완료: #{count}건")
    count
  end
end
