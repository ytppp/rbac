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

ActiveRecord::Schema[7.1].define(version: 2025_01_01_000007) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "note_likes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "note_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["note_id"], name: "index_note_likes_on_note_id"
    t.index ["user_id", "note_id"], name: "index_note_likes_on_user_id_and_note_id", unique: true
  end

  create_table "notes", force: :cascade do |t|
    t.string "title", null: false
    t.string "cover_url", null: false
    t.decimal "cover_ratio", precision: 6, scale: 4, default: "1.0", null: false
    t.string "author_name", null: false
    t.string "avatar_color", default: "#ff6b6b", null: false
    t.integer "likes_count", default: 0, null: false
    t.string "channel", null: false
    t.integer "sort", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["channel"], name: "index_notes_on_channel"
    t.index ["sort"], name: "index_notes_on_sort"
  end

  create_table "permissions", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.integer "type", default: 0, null: false
    t.bigint "parent_id"
    t.string "path"
    t.string "component"
    t.string "icon"
    t.integer "sort", default: 0, null: false
    t.integer "status", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_permissions_on_code", unique: true
    t.index ["parent_id"], name: "index_permissions_on_parent_id"
    t.index ["type", "status"], name: "index_permissions_on_type_and_status"
  end

  create_table "role_permissions", force: :cascade do |t|
    t.bigint "role_id", null: false
    t.bigint "permission_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["permission_id"], name: "index_role_permissions_on_permission_id"
    t.index ["role_id", "permission_id"], name: "index_role_permissions_on_role_id_and_permission_id", unique: true
    t.index ["role_id"], name: "index_role_permissions_on_role_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.string "description"
    t.integer "status", default: 1, null: false
    t.boolean "built_in", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_roles_on_code", unique: true
    t.index ["status"], name: "index_roles_on_status"
  end

  create_table "user_roles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "role_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["role_id"], name: "index_user_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_user_roles_on_user_id_and_role_id", unique: true
    t.index ["user_id"], name: "index_user_roles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.integer "status", default: 1, null: false
    t.datetime "last_login_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true
    t.index ["status"], name: "index_users_on_status"
  end

  add_foreign_key "note_likes", "notes", on_delete: :cascade
  add_foreign_key "note_likes", "users", on_delete: :cascade
  add_foreign_key "permissions", "permissions", column: "parent_id", on_delete: :restrict
  add_foreign_key "role_permissions", "permissions", on_delete: :cascade
  add_foreign_key "role_permissions", "roles", on_delete: :cascade
  add_foreign_key "user_roles", "roles", on_delete: :cascade
  add_foreign_key "user_roles", "users", on_delete: :cascade
end
