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

ActiveRecord::Schema[8.1].define(version: 2026_10_22_001000) do
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

  create_table "campaign_deliveries", force: :cascade do |t|
    t.integer "campaign_id", null: false
    t.integer "anony_customer_id", null: false
    t.string "status", default: "pending", null: false
    t.string "channel", default: "internal", null: false
    t.text "message"
    t.text "failure_reason"
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["anony_customer_id"], name: "index_campaign_deliveries_on_anony_customer_id"
    t.index ["campaign_id", "anony_customer_id"], name: "index_campaign_deliveries_on_campaign_id_and_anony_customer_id", unique: true
    t.index ["campaign_id"], name: "index_campaign_deliveries_on_campaign_id"
    t.index ["status"], name: "index_campaign_deliveries_on_status"
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
    t.text "failure_reason"
    t.index ["campaign_type"], name: "index_campaigns_on_campaign_type"
    t.index ["product_id"], name: "index_campaigns_on_product_id"
    t.index ["scheduled_at"], name: "index_campaigns_on_scheduled_at"
    t.index ["status"], name: "index_campaigns_on_status"
  end

  create_table "characters", force: :cascade do |t|
    t.string "name", null: false
    t.string "handle", null: false
    t.integer "age"
    t.string "birthplace"
    t.integer "age_band"
    t.string "style_axis"
    t.string "wardrobe"
    t.text "personality"
    t.string "status", default: "planned"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "height_cm"
    t.string "top_size"
    t.string "bottom_size"
    t.integer "shoe_mm"
    t.string "body_type"
    t.index ["handle"], name: "index_characters_on_handle", unique: true
  end

  create_table "image_processings", force: :cascade do |t|
    t.integer "product_id", null: false
    t.string "kind", null: false
    t.string "status", default: "pending", null: false
    t.string "provider"
    t.integer "cost_cents", default: 0, null: false
    t.text "error_message"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_image_processings_on_created_at"
    t.index ["product_id", "kind"], name: "index_image_processings_on_product_id_and_kind"
    t.index ["status"], name: "index_image_processings_on_status"
  end

  create_table "image_quality_checks", force: :cascade do |t|
    t.string "product_code", null: false
    t.text "image_url"
    t.string "image_sha256"
    t.string "verdict"
    t.integer "score"
    t.text "reason"
    t.text "metrics_json"
    t.string "vision_model"
    t.datetime "checked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_code", "image_sha256"], name: "index_image_quality_checks_on_product_code_and_image_sha256"
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
    t.integer "shipping_address_id"
    t.datetime "delivered_at"
    t.string "checkout_number"
    t.index ["anony_customer_id"], name: "index_orders_on_anony_customer_id"
    t.index ["checkout_number"], name: "index_orders_on_checkout_number"
    t.index ["created_at"], name: "index_orders_on_created_at"
    t.index ["order_number"], name: "index_orders_on_order_number", unique: true
    t.index ["product_id"], name: "index_orders_on_product_id"
    t.index ["shipping_address_id"], name: "index_orders_on_shipping_address_id"
    t.index ["status"], name: "index_orders_on_status"
    t.index ["variant_id"], name: "index_orders_on_variant_id"
  end

  create_table "product_analyses", force: :cascade do |t|
    t.integer "product_id", null: false
    t.string "status", default: "pending", null: false
    t.integer "character_id"
    t.integer "alt_character_id"
    t.string "concept_angle"
    t.string "concept_title"
    t.string "hook_line"
    t.string "season"
    t.string "style_axis"
    t.integer "target_age_band"
    t.text "attributes_json"
    t.text "reasoning"
    t.float "confidence"
    t.integer "target_units"
    t.integer "target_units_override"
    t.decimal "target_revenue", precision: 12, scale: 2
    t.text "assumptions_json"
    t.string "model"
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.decimal "cost_usd", precision: 10, scale: 6
    t.text "error_message"
    t.datetime "analyzed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "manually_assigned", default: false, null: false
    t.text "ranking_json"
    t.index ["alt_character_id"], name: "index_product_analyses_on_alt_character_id"
    t.index ["character_id"], name: "index_product_analyses_on_character_id"
    t.index ["product_id"], name: "index_product_analyses_on_product_id"
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
    t.decimal "supply_price", precision: 10, scale: 2
    t.integer "supplier_import_id"
    t.string "supplier_product_code"
    t.integer "supplier_id"
    t.boolean "cutout_adopted", default: false, null: false
    t.integer "worn_character_id"
    t.string "worn_size"
    t.string "status", default: "published", null: false
    t.datetime "published_at"
    t.integer "published_by_id"
    t.text "info_notice"
    t.index ["status"], name: "index_products_on_status"
    t.index ["supplier_id", "supplier_product_code"], name: "index_products_on_supplier_id_and_supplier_product_code"
    t.index ["supplier_id"], name: "index_products_on_supplier_id"
    t.index ["supplier_import_id"], name: "index_products_on_supplier_import_id"
    t.index ["worn_character_id"], name: "index_products_on_worn_character_id"
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
    t.datetime "confirmation_token_expires_at"
    t.datetime "confirmation_token_used_at"
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
    t.string "fit"
    t.index ["product_id"], name: "index_reviews_on_product_id"
    t.index ["user_id"], name: "index_reviews_on_user_id"
  end

  create_table "shipping_addresses", force: :cascade do |t|
    t.string "recipient_name", null: false
    t.string "phone", null: false
    t.string "postal_code", null: false
    t.string "address1", null: false
    t.string "address2"
    t.string "country_code", default: "KR", null: false
    t.boolean "save_consent", default: false, null: false
    t.datetime "consented_at"
    t.datetime "purge_after"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["purge_after"], name: "index_shipping_addresses_on_purge_after"
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

  create_table "supplier_imports", force: :cascade do |t|
    t.integer "supplier_id"
    t.string "status", default: "pending"
    t.integer "total_rows", default: 0
    t.integer "imported_rows", default: 0
    t.integer "updated_rows", default: 0
    t.integer "failed_rows", default: 0
    t.text "row_results"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["supplier_id"], name: "index_supplier_imports_on_supplier_id"
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

  create_table "trend_snapshots", force: :cascade do |t|
    t.string "source", null: false
    t.string "series_name", null: false
    t.date "period_start", null: false
    t.decimal "ratio", precision: 7, scale: 2, null: false
    t.integer "age_band"
    t.string "gender"
    t.datetime "imported_at", null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "source, series_name, period_start, COALESCE(age_band, 0), COALESCE(gender, '')", name: "index_trend_snapshots_nullable_identity", unique: true
    t.index ["source", "series_name", "period_start", "age_band", "gender"], name: "index_trend_snapshots_identity", unique: true
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
  add_foreign_key "campaign_deliveries", "anony_customers"
  add_foreign_key "campaign_deliveries", "campaigns"
  add_foreign_key "campaigns", "products"
  add_foreign_key "image_processings", "products"
  add_foreign_key "notifications", "variants"
  add_foreign_key "orders", "anony_customers"
  add_foreign_key "orders", "products"
  add_foreign_key "orders", "variants"
  add_foreign_key "product_analyses", "characters"
  add_foreign_key "product_analyses", "products"
  add_foreign_key "products", "characters", column: "worn_character_id"
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
