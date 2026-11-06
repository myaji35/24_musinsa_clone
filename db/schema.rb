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

ActiveRecord::Schema[8.1].define(version: 2026_11_06_000181) do
  create_table "accounts", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_accounts_on_slug", unique: true
  end

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

  create_table "content_uploads", force: :cascade do |t|
    t.integer "product_id", null: false
    t.integer "character_id", null: false
    t.string "kind", null: false
    t.integer "slot", null: false
    t.string "sha256", null: false
    t.string "source_row"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["character_id"], name: "index_content_uploads_on_character_id"
    t.index ["product_id", "character_id", "kind", "slot"], name: "idx_on_product_id_character_id_kind_slot_9c7d0cbbfa", unique: true
    t.index ["product_id"], name: "index_content_uploads_on_product_id"
    t.index ["sha256"], name: "index_content_uploads_on_sha256", unique: true
  end

  create_table "feedbacks", force: :cascade do |t|
    t.string "kind", default: "other", null: false
    t.text "body", null: false
    t.string "source", default: "customer_web", null: false
    t.string "status", default: "new", null: false
    t.string "page_url", limit: 500
    t.integer "product_id"
    t.text "contact_email"
    t.boolean "contact_consent", default: false, null: false
    t.datetime "contact_purged_at"
    t.datetime "answered_at"
    t.string "reporter_hash"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "factory_feedback_id"
    t.string "factory_issue_id"
    t.string "factory_action"
    t.text "factory_flags"
    t.datetime "forwarded_at"
    t.index ["created_at"], name: "index_feedbacks_on_created_at"
    t.index ["kind"], name: "index_feedbacks_on_kind"
    t.index ["product_id"], name: "index_feedbacks_on_product_id"
    t.index ["reporter_hash"], name: "index_feedbacks_on_reporter_hash"
    t.index ["status"], name: "index_feedbacks_on_status"
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

  create_table "kakao_devices", force: :cascade do |t|
    t.integer "account_id", null: false
    t.string "name", null: false
    t.string "token_digest", null: false
    t.datetime "last_seen_at"
    t.datetime "last_collected_at"
    t.datetime "last_error_at"
    t.datetime "revoked_at"
    t.text "last_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "realtime_enabled", default: true
    t.boolean "backfill_enabled", default: true
    t.string "backfill_window", default: "03:00-05:00"
    t.string "time_zone", default: "Asia/Seoul"
    t.integer "backfill_max_rooms", default: 5
    t.integer "backfill_limit_per_room", default: 100
    t.boolean "open_window_enabled", default: false
    t.integer "open_window_poll_seconds", default: 300
    t.string "agent_version"
    t.json "permissions", default: {}
    t.boolean "ok"
    t.datetime "last_realtime_at"
    t.datetime "last_backfill_at"
    t.index ["account_id"], name: "index_kakao_devices_on_account_id"
    t.index ["token_digest"], name: "index_kakao_devices_on_token_digest", unique: true
  end

  create_table "kakao_extraction_messages", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "kakao_extraction_id", null: false
    t.integer "kakao_message_id", null: false
    t.index ["account_id"], name: "index_kakao_extraction_messages_on_account_id"
    t.index ["kakao_extraction_id", "kakao_message_id"], name: "idx_kakao_extraction_evidence", unique: true
    t.index ["kakao_extraction_id"], name: "index_kakao_extraction_messages_on_kakao_extraction_id"
    t.index ["kakao_message_id"], name: "index_kakao_extraction_messages_on_kakao_message_id"
  end

  create_table "kakao_extractions", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "kakao_room_id", null: false
    t.integer "supplier_id"
    t.string "kind", null: false
    t.text "summary", null: false
    t.date "date"
    t.string "time_text"
    t.integer "quantity"
    t.string "unit"
    t.decimal "amount", precision: 12, scale: 2
    t.string "product_hint"
    t.string "counterparty_hint"
    t.decimal "confidence"
    t.string "status", default: "pending", null: false
    t.string "applied_type"
    t.integer "applied_id"
    t.integer "reviewed_by_user_id"
    t.datetime "reviewed_at"
    t.string "model_name"
    t.boolean "source_changed", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "progress", default: "unknown", null: false
    t.index ["account_id"], name: "index_kakao_extractions_on_account_id"
    t.index ["applied_type", "applied_id"], name: "index_kakao_extractions_on_applied"
    t.index ["kakao_room_id"], name: "index_kakao_extractions_on_kakao_room_id"
    t.index ["reviewed_by_user_id"], name: "index_kakao_extractions_on_reviewed_by_user_id"
    t.index ["supplier_id"], name: "index_kakao_extractions_on_supplier_id"
  end

  create_table "kakao_message_external_ids", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "kakao_message_id", null: false
    t.string "external_id", null: false
    t.index ["account_id", "external_id"], name: "index_kakao_message_external_ids_on_account_id_and_external_id", unique: true
    t.index ["kakao_message_id"], name: "index_kakao_message_external_ids_on_kakao_message_id"
  end

  create_table "kakao_messages", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "kakao_room_id", null: false
    t.integer "kakao_device_id"
    t.string "author"
    t.string "time_raw"
    t.text "body", null: false
    t.date "sent_on"
    t.datetime "sent_at"
    t.string "digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source"
    t.string "sources"
    t.string "external_id"
    t.string "time_precision"
    t.string "match_key"
    t.boolean "truncated", default: false
    t.boolean "is_mine", default: false
    t.boolean "needs_extraction", default: true
    t.boolean "extraction_gap", default: false, null: false
    t.index ["account_id", "external_id"], name: "index_kakao_messages_on_account_id_and_external_id", unique: true
    t.index ["account_id", "kakao_room_id", "match_key", "sent_at"], name: "idx_on_account_id_kakao_room_id_match_key_sent_at_88eb2d5d43"
    t.index ["account_id"], name: "index_kakao_messages_on_account_id"
    t.index ["kakao_device_id"], name: "index_kakao_messages_on_kakao_device_id"
    t.index ["kakao_room_id", "sent_at"], name: "index_kakao_messages_on_kakao_room_id_and_sent_at"
    t.index ["kakao_room_id"], name: "index_kakao_messages_on_kakao_room_id"
  end

  create_table "kakao_rooms", force: :cascade do |t|
    t.integer "account_id", null: false
    t.string "name", null: false
    t.boolean "active", default: true
    t.datetime "last_collected_at"
    t.integer "last_message_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "aliases"
    t.integer "supplier_id"
    t.datetime "extraction_scheduled_at"
    t.text "last_extraction_error"
    t.index ["account_id", "name"], name: "index_kakao_rooms_on_account_id_and_name", unique: true
    t.index ["account_id"], name: "index_kakao_rooms_on_account_id"
    t.index ["supplier_id"], name: "index_kakao_rooms_on_supplier_id"
  end

  create_table "ledger_entries", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "supplier_id", null: false
    t.string "entry_type", null: false
    t.date "occurred_on", null: false
    t.string "item_name"
    t.integer "quantity"
    t.string "unit"
    t.decimal "unit_price", precision: 12, scale: 2
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.date "due_on"
    t.text "memo"
    t.string "source_type"
    t.integer "source_id"
    t.integer "created_by_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "supplier_id", "occurred_on"], name: "idx_on_account_id_supplier_id_occurred_on_5b137852c7"
    t.index ["account_id"], name: "index_ledger_entries_on_account_id"
    t.index ["created_by_user_id"], name: "index_ledger_entries_on_created_by_user_id"
    t.index ["source_type", "source_id", "entry_type"], name: "index_ledger_purchase_source", unique: true, where: "source_id IS NOT NULL AND entry_type = 'purchase'"
    t.index ["source_type", "source_id"], name: "index_ledger_entries_on_source"
    t.index ["supplier_id"], name: "index_ledger_entries_on_supplier_id"
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

  create_table "order_shipping_records", force: :cascade do |t|
    t.integer "order_id", null: false
    t.text "recipient_name", null: false
    t.text "phone", null: false
    t.text "postal_code", null: false
    t.text "address1", null: false
    t.text "address2"
    t.string "country_code", default: "KR", null: false
    t.datetime "retain_until", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_shipping_records_on_order_id", unique: true
    t.index ["retain_until"], name: "index_order_shipping_records_on_retain_until"
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
    t.integer "picked_character_id"
    t.datetime "picked_at"
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
    t.text "selling_points"
    t.text "spec"
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

  create_table "schedule_events", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "supplier_id"
    t.string "title", null: false
    t.date "starts_on", null: false
    t.time "starts_at_time"
    t.string "kind", default: "other", null: false
    t.string "status", default: "open", null: false
    t.text "memo"
    t.string "source_type"
    t.integer "source_id"
    t.integer "created_by_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "starts_on"], name: "index_schedule_events_on_account_id_and_starts_on"
    t.index ["account_id"], name: "index_schedule_events_on_account_id"
    t.index ["created_by_user_id"], name: "index_schedule_events_on_created_by_user_id"
    t.index ["source_type", "source_id"], name: "index_schedule_events_on_source"
    t.index ["supplier_id"], name: "index_schedule_events_on_supplier_id"
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

  create_table "supplier_accounts", force: :cascade do |t|
    t.integer "supplier_id", null: false
    t.string "email", null: false
    t.string "name"
    t.string "password_digest", null: false
    t.datetime "last_sign_in_at"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_supplier_accounts_on_email", unique: true
    t.index ["supplier_id"], name: "index_supplier_accounts_on_supplier_id"
  end

  create_table "supplier_claims", force: :cascade do |t|
    t.integer "supplier_id", null: false
    t.integer "purchase_order_id"
    t.integer "variant_id"
    t.string "claim_type", null: false
    t.integer "quantity"
    t.text "description", null: false
    t.string "status", default: "open", null: false
    t.text "supplier_response"
    t.datetime "responded_at"
    t.datetime "resolved_at"
    t.integer "created_by_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_user_id"], name: "index_supplier_claims_on_created_by_user_id"
    t.index ["purchase_order_id"], name: "index_supplier_claims_on_purchase_order_id"
    t.index ["supplier_id"], name: "index_supplier_claims_on_supplier_id"
    t.index ["variant_id"], name: "index_supplier_claims_on_variant_id"
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
    t.integer "account_id", null: false
    t.string "kind", default: "purchase", null: false
    t.string "business_number"
    t.index ["account_id", "name"], name: "index_suppliers_on_account_id_and_name", unique: true
    t.index ["account_id"], name: "index_suppliers_on_account_id"
    t.index ["active"], name: "index_suppliers_on_active"
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
    t.integer "account_id"
    t.index ["account_id"], name: "index_users_on_account_id"
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
  add_foreign_key "content_uploads", "characters"
  add_foreign_key "content_uploads", "products"
  add_foreign_key "feedbacks", "products", on_delete: :nullify
  add_foreign_key "image_processings", "products"
  add_foreign_key "kakao_devices", "accounts"
  add_foreign_key "kakao_extraction_messages", "accounts"
  add_foreign_key "kakao_extraction_messages", "kakao_extractions"
  add_foreign_key "kakao_extraction_messages", "kakao_messages"
  add_foreign_key "kakao_extractions", "accounts"
  add_foreign_key "kakao_extractions", "kakao_rooms"
  add_foreign_key "kakao_extractions", "suppliers"
  add_foreign_key "kakao_extractions", "users", column: "reviewed_by_user_id"
  add_foreign_key "kakao_message_external_ids", "accounts"
  add_foreign_key "kakao_message_external_ids", "kakao_messages"
  add_foreign_key "kakao_messages", "accounts"
  add_foreign_key "kakao_messages", "kakao_devices"
  add_foreign_key "kakao_messages", "kakao_rooms"
  add_foreign_key "kakao_rooms", "accounts"
  add_foreign_key "kakao_rooms", "suppliers"
  add_foreign_key "ledger_entries", "accounts"
  add_foreign_key "ledger_entries", "suppliers"
  add_foreign_key "ledger_entries", "users", column: "created_by_user_id"
  add_foreign_key "notifications", "variants"
  add_foreign_key "order_shipping_records", "orders"
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
  add_foreign_key "schedule_events", "accounts"
  add_foreign_key "schedule_events", "suppliers"
  add_foreign_key "schedule_events", "users", column: "created_by_user_id"
  add_foreign_key "snap_products", "products"
  add_foreign_key "snap_products", "snaps"
  add_foreign_key "snaps", "users"
  add_foreign_key "stock_logs", "variants"
  add_foreign_key "supplier_accounts", "suppliers"
  add_foreign_key "supplier_claims", "purchase_orders", on_delete: :nullify
  add_foreign_key "supplier_claims", "suppliers"
  add_foreign_key "supplier_claims", "users", column: "created_by_user_id", on_delete: :nullify
  add_foreign_key "supplier_claims", "variants", on_delete: :nullify
  add_foreign_key "suppliers", "accounts"
  add_foreign_key "users", "accounts"
  add_foreign_key "variants", "products"
end
