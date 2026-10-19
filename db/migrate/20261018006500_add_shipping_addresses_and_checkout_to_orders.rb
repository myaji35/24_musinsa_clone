class AddShippingAddressesAndCheckoutToOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :shipping_addresses do |t|
      t.string :recipient_name, null: false
      t.string :phone, null: false
      t.string :postal_code, null: false
      t.string :address1, null: false
      t.string :address2
      t.string :country_code, default: "KR", null: false
      t.boolean :save_consent, default: false, null: false
      t.datetime :consented_at
      t.datetime :purge_after, index: true
      t.timestamps
    end

    add_column :orders, :shipping_address_id, :integer
    add_index :orders, :shipping_address_id
    add_column :orders, :delivered_at, :datetime
    add_column :orders, :checkout_number, :string
    add_index :orders, :checkout_number
  end
end
