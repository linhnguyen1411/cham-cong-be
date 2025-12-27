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

ActiveRecord::Schema[7.1].define(version: 2025_12_26_101438) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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

  create_table "app_settings", force: :cascade do |t|
    t.string "company_name"
    t.boolean "require_ip_check", default: true
    t.json "allowed_ips", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "max_user_off_days_per_week", default: 1, null: false
    t.integer "max_user_off_shifts_per_week", default: 2, null: false
    t.integer "max_shift_off_count_per_day", default: 1, null: false
  end

  create_table "branches", force: :cascade do |t|
    t.string "name"
    t.string "address"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "departments", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "ip_address"
  end

  create_table "positions", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.bigint "branch_id"
    t.bigint "department_id"
    t.integer "level", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_positions_on_branch_id"
    t.index ["department_id"], name: "index_positions_on_department_id"
    t.index ["name", "branch_id", "department_id"], name: "idx_positions_unique", unique: true
  end

  create_table "shift_registrations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "work_shift_id", null: false
    t.date "work_date", null: false
    t.date "week_start", null: false
    t.integer "status", default: 0
    t.text "note"
    t.text "admin_note"
    t.bigint "approved_by_id"
    t.datetime "approved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_shift_registrations_on_approved_by_id"
    t.index ["status"], name: "index_shift_registrations_on_status"
    t.index ["user_id", "work_date", "work_shift_id"], name: "idx_shift_reg_user_date_shift", unique: true
    t.index ["user_id"], name: "index_shift_registrations_on_user_id"
    t.index ["week_start"], name: "index_shift_registrations_on_week_start"
    t.index ["work_shift_id"], name: "index_shift_registrations_on_work_shift_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "username", null: false
    t.string "password_digest", null: false
    t.string "full_name"
    t.integer "role", default: 0
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "address"
    t.string "phone"
    t.date "birthday"
    t.bigint "branch_id"
    t.string "work_address"
    t.bigint "department_id"
    t.bigint "position_id"
    t.integer "work_schedule_type", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.index ["branch_id"], name: "index_users_on_branch_id"
    t.index ["department_id"], name: "index_users_on_department_id"
    t.index ["position_id"], name: "index_users_on_position_id"
    t.index ["status"], name: "index_users_on_status"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "work_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "start_time"
    t.datetime "end_time"
    t.integer "duration_minutes"
    t.text "report"
    t.string "report_mood"
    t.text "handover_notes"
    t.json "handover_items", default: []
    t.json "images", default: []
    t.string "ip_address"
    t.date "date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_on_time"
    t.integer "minutes_late", default: 0
    t.bigint "work_shift_id"
    t.boolean "is_early_checkout", default: false
    t.integer "minutes_before_end", default: 0
    t.text "work_summary"
    t.text "challenges"
    t.text "suggestions"
    t.text "notes"
    t.boolean "forgot_checkout", default: false
    t.bigint "shift_registration_id"
    t.index ["shift_registration_id"], name: "index_work_sessions_on_shift_registration_id"
    t.index ["user_id"], name: "index_work_sessions_on_user_id"
    t.index ["work_shift_id"], name: "index_work_sessions_on_work_shift_id"
  end

  create_table "work_shifts", force: :cascade do |t|
    t.string "name", null: false
    t.string "start_time", null: false
    t.string "end_time", null: false
    t.integer "late_threshold", default: 30
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "department_id"
    t.index ["department_id"], name: "index_work_shifts_on_department_id"
    t.index ["name"], name: "index_work_shifts_on_name", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "positions", "branches"
  add_foreign_key "positions", "departments"
  add_foreign_key "shift_registrations", "users"
  add_foreign_key "shift_registrations", "users", column: "approved_by_id"
  add_foreign_key "shift_registrations", "work_shifts"
  add_foreign_key "users", "branches"
  add_foreign_key "users", "departments"
  add_foreign_key "users", "positions"
  add_foreign_key "work_sessions", "shift_registrations"
  add_foreign_key "work_sessions", "users"
  add_foreign_key "work_sessions", "work_shifts"
  add_foreign_key "work_shifts", "departments"
end
