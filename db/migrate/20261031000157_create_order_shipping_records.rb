class CreateOrderShippingRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :order_shipping_records do |t|
      t.references :order, null: false, foreign_key: true, index: { unique: true }
      t.text :recipient_name, null: false
      t.text :phone, null: false
      t.text :postal_code, null: false
      t.text :address1, null: false
      t.text :address2
      t.string :country_code, default: "KR", null: false
      t.datetime :retain_until, null: false, index: true
      t.timestamps
    end
  end
end
