class CreateSupplierClaims < ActiveRecord::Migration[8.1]
  def change
    create_table :supplier_claims do |t|
      t.references :supplier, null: false, foreign_key: true
      t.references :purchase_order, foreign_key: { on_delete: :nullify }
      t.references :variant, foreign_key: { on_delete: :nullify }
      t.string :claim_type, null: false
      t.integer :quantity
      t.text :description, null: false
      t.string :status, null: false, default: "open"
      t.text :supplier_response
      t.datetime :responded_at
      t.datetime :resolved_at
      t.references :created_by_user, foreign_key: { to_table: :users, on_delete: :nullify }
      t.timestamps
    end
  end
end
