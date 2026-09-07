# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_09_07_000002) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "anony_customers", force: :cascade do |t|
    t.string "uuid", null: false
    t.string "zip_prefix", limit: 3
    t.string "phone_suffix", limit: 4
    t.integer "birth_year"
    t.text "preference_tags"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["phone_suffix", "birth_year"], name: "index_anony_customers_on_phone_suffix_and_birth_year"
    t.index ["uuid"], name: "index_anony_customers_on_uuid", unique: true
    t.index ["zip_prefix"], name: "index_anony_customers_on_zip_prefix"
  end

  create_table "campaigns", force: :cascade do |t|
    t.string "name", null: false
    t.string "campaign_type", null: false
    t.text "target_segment"
    t.integer "product_id"
    t.text "message_template"
    t.string "status", default: "draft"
    t.datetime "scheduled_at"
    t.datetime "sent_at"
    t.integer "target_count", default: 0
    t.integer "sent_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_type"], name: "index_campaigns_on_campaign_type"
    t.index ["product_id"], name: "index_campaigns_on_product_id"
    t.index ["scheduled_at"], name: "index_campaigns_on_scheduled_at"
    t.index ["status"], name: "index_campaigns_on_status"
  end

  create_table "notifications", force: :cascade do |t|
    t.integer "variant_id", null: false
    t.string "notification_type", null: false
    t.text "message"
    t.string "status", default: "pending"
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["notification_type"], name: "index_notifications_on_notification_type"
    t.index ["sent_at"], name: "index_notifications_on_sent_at"
    t.index ["status"], name: "index_notifications_on_status"
    t.index ["variant_id"], name: "index_notifications_on_variant_id"
  end

  create_table "orders", force: :cascade do |t|
    t.integer "anony_customer_id", null: false
    t.integer "product_id", null: false
    t.integer "variant_id", null: false
    t.integer "quantity", default: 1, null: false
    t.decimal "total_price", precision: 10, scale: 2, null: false
    t.string "status", default: "pending"
    t.string "order_number", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["anony_customer_id"], name: "index_orders_on_anony_customer_id"
    t.index ["created_at"], name: "index_orders_on_created_at"
    t.index ["order_number"], name: "index_orders_on_order_number", unique: true
    t.index ["product_id"], name: "index_orders_on_product_id"
    t.index ["status"], name: "index_orders_on_status"
    t.index ["variant_id"], name: "index_orders_on_variant_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.decimal "price"
    t.integer "stock"
    t.string "category"
    t.string "brand"
    t.string "gender"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "views_count"
    t.integer "sales_count"
    t.string "image_url"
    t.text "ai_attributes"
    t.text "badges"
    t.boolean "is_new", default: false
    t.datetime "restocked_at"
  end

  create_table "purchase_order_items", force: :cascade do |t|
    t.integer "purchase_order_id", null: false
    t.integer "variant_id", null: false
    t.integer "quantity", null: false
    t.decimal "unit_price", precision: 10, scale: 2, null: false
    t.decimal "subtotal", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["purchase_order_id", "variant_id"], name: "index_po_items_on_po_and_variant", unique: true
    t.index ["purchase_order_id"], name: "index_purchase_order_items_on_purchase_order_id"
    t.index ["variant_id"], name: "index_purchase_order_items_on_variant_id"
  end

  create_table "purchase_orders", force: :cascade do |t|
    t.integer "supplier_id", null: false
    t.string "order_number", null: false
    t.string "status", default: "draft"
    t.date "expected_delivery_date"
    t.decimal "total_amount", precision: 10, scale: 2, default: "0.0"
    t.text "notes"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "received_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_purchase_orders_on_confirmation_token"
    t.index ["order_number"], name: "index_purchase_orders_on_order_number", unique: true
    t.index ["status"], name: "index_purchase_orders_on_status"
    t.index ["supplier_id"], name: "index_purchase_orders_on_supplier_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.text "content"
    t.integer "rating"
    t.integer "user_id", null: false
    t.integer "product_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "height"
    t.integer "weight"
    t.string "size_purchased"
    t.string "photo_url"
    t.index ["product_id"], name: "index_reviews_on_product_id"
    t.index ["user_id"], name: "index_reviews_on_user_id"
  end

  create_table "snap_products", force: :cascade do |t|
    t.integer "snap_id", null: false
    t.integer "product_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_snap_products_on_product_id"
    t.index ["snap_id"], name: "index_snap_products_on_snap_id"
  end

  create_table "snaps", force: :cascade do |t|
    t.text "content"
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_snaps_on_user_id"
  end

  create_table "stock_logs", force: :cascade do |t|
    t.integer "variant_id", null: false
    t.string "log_type", null: false
    t.integer "quantity", null: false
    t.string "supplier"
    t.decimal "unit_cost", precision: 10, scale: 2
    t.integer "order_id"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_stock_logs_on_created_at"
    t.index ["log_type"], name: "index_stock_logs_on_log_type"
    t.index ["variant_id"], name: "index_stock_logs_on_variant_id"
  end

  create_table "suppliers", force: :cascade do |t|
    t.string "name", null: false
    t.string "contact_person"
    t.string "phone", null: false
    t.string "email"
    t.text "address"
    t.string "payment_terms"
    t.text "notes"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_suppliers_on_active"
    t.index ["name"], name: "index_suppliers_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "password_digest"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "variants", force: :cascade do |t|
    t.integer "product_id", null: false
    t.string "sku_code"
    t.string "color"
    t.string "size"
    t.string "barcode"
    t.integer "stock"
    t.integer "min_stock"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_variants_on_product_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "campaigns", "products"
  add_foreign_key "notifications", "variants"
  add_foreign_key "orders", "anony_customers"
  add_foreign_key "orders", "products"
  add_foreign_key "orders", "variants"
  add_foreign_key "purchase_order_items", "purchase_orders"
  add_foreign_key "purchase_order_items", "variants"
  add_foreign_key "purchase_orders", "suppliers"
  add_foreign_key "reviews", "products"
  add_foreign_key "reviews", "users"
  add_foreign_key "snap_products", "products"
  add_foreign_key "snap_products", "snaps"
  add_foreign_key "snaps", "users"
  add_foreign_key "stock_logs", "variants"
  add_foreign_key "variants", "products"
end
