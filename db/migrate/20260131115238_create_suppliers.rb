class CreateSuppliers < ActiveRecord::Migration[7.2]
  def change
    create_table :suppliers do |t|
      t.string :name, null: false
      t.string :contact_person
      t.string :phone, null: false
      t.string :email
      t.text :address
      t.string :payment_terms # 예: "30일 후불", "선불"
      t.text :notes
      t.boolean :active, default: true # 활성 거래처 여부

      t.timestamps
    end

    add_index :suppliers, :name, unique: true
    add_index :suppliers, :active
  end
end
