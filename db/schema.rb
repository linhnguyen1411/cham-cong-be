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

ActiveRecord::Schema[7.1].define(version: 2025_12_10_013023) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "app_settings", force: :cascade do |t|
    t.string "company_name"
    t.boolean "require_ip_check", default: true
    t.json "allowed_ips", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "username", null: false
    t.string "password_digest", null: false
    t.string "full_name"
    t.integer "role", default: 0
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["name"], name: "index_work_shifts_on_name", unique: true
  end

  add_foreign_key "work_sessions", "users"
  add_foreign_key "work_sessions", "work_shifts"
end
