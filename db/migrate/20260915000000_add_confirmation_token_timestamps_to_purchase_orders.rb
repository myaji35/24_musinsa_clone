class AddConfirmationTokenTimestampsToPurchaseOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :purchase_orders, :confirmation_token_expires_at, :datetime
    add_column :purchase_orders, :confirmation_token_used_at, :datetime
  end
end
