class StockHoldExpiryJob < ApplicationJob
  queue_as :default

  def perform
    Inventory::StockHoldService.release_expired
  end
end
