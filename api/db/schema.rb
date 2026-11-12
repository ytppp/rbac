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

ActiveRecord::Schema[7.1].define(version: 2026_11_12_000007) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "comment_likes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "comment_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["comment_id"], name: "index_comment_likes_on_comment_id"
    t.index ["user_id", "comment_id"], name: "index_comment_likes_on_user_id_and_comment_id", unique: true
    t.index ["user_id"], name: "index_comment_likes_on_user_id"
  end

  create_table "comments", force: :cascade do |t|
    t.bigint "note_id", null: false
    t.bigint "user_id", null: false
    t.bigint "parent_id"
    t.text "content", null: false
    t.integer "likes_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["note_id", "created_at"], name: "index_comments_on_note_id_and_created_at"
    t.index ["note_id"], name: "index_comments_on_note_id"
    t.index ["parent_id"], name: "index_comments_on_parent_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "note_favorites", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "note_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["note_id"], name: "index_note_favorites_on_note_id"
    t.index ["user_id", "note_id"], name: "index_note_favorites_on_user_id_and_note_id", unique: true
    t.index ["user_id"], name: "index_note_favorites_on_user_id"
  end

  create_table "note_likes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "note_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["note_id"], name: "index_note_likes_on_note_id"
    t.index ["user_id", "note_id"], name: "index_note_likes_on_user_id_and_note_id", unique: true
  end

  create_table "note_tags", force: :cascade do |t|
    t.bigint "note_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["note_id", "tag_id"], name: "index_note_tags_on_note_id_and_tag_id", unique: true
    t.index ["note_id"], name: "index_note_tags_on_note_id"
    t.index ["tag_id"], name: "index_note_tags_on_tag_id"
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
    t.bigint "user_id"
    t.text "content", default: "", null: false
    t.jsonb "sections", default: [], null: false
    t.integer "status", default: 2, null: false
    t.index ["channel"], name: "index_notes_on_channel"
    t.index ["sort"], name: "index_notes_on_sort"
    t.index ["status"], name: "index_notes_on_status"
    t.index ["user_id"], name: "index_notes_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "actor_id"
    t.string "action", null: false
    t.bigint "note_id"
    t.bigint "comment_id"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["note_id"], name: "index_notifications_on_note_id"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
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

  create_table "reports", force: :cascade do |t|
    t.bigint "note_id", null: false
    t.bigint "user_id", null: false
    t.string "reason", null: false
    t.text "detail"
    t.integer "status", default: 0, null: false
    t.bigint "handled_by"
    t.datetime "handled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["note_id", "user_id"], name: "index_reports_on_note_id_and_user_id", unique: true
    t.index ["note_id"], name: "index_reports_on_note_id"
    t.index ["status"], name: "index_reports_on_status"
    t.index ["user_id"], name: "index_reports_on_user_id"
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

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.integer "notes_count", default: 0, null: false
    t.integer "sort", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
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
    t.string "avatar_url"
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true
    t.index ["status"], name: "index_users_on_status"
  end

  add_foreign_key "comment_likes", "comments", on_delete: :cascade
  add_foreign_key "comment_likes", "users", on_delete: :cascade
  add_foreign_key "comments", "comments", column: "parent_id", on_delete: :cascade
  add_foreign_key "comments", "notes", on_delete: :cascade
  add_foreign_key "comments", "users", on_delete: :cascade
  add_foreign_key "note_favorites", "notes", on_delete: :cascade
  add_foreign_key "note_favorites", "users", on_delete: :cascade
  add_foreign_key "note_likes", "notes", on_delete: :cascade
  add_foreign_key "note_likes", "users", on_delete: :cascade
  add_foreign_key "note_tags", "notes", on_delete: :cascade
  add_foreign_key "note_tags", "tags", on_delete: :cascade
  add_foreign_key "notes", "users", on_delete: :nullify
  add_foreign_key "notifications", "notes", on_delete: :cascade
  add_foreign_key "notifications", "users", column: "actor_id", on_delete: :nullify
  add_foreign_key "notifications", "users", on_delete: :cascade
  add_foreign_key "permissions", "permissions", column: "parent_id", on_delete: :restrict
  add_foreign_key "reports", "notes", on_delete: :cascade
  add_foreign_key "reports", "users", column: "handled_by", on_delete: :nullify
  add_foreign_key "reports", "users", on_delete: :cascade
  add_foreign_key "role_permissions", "permissions", on_delete: :cascade
  add_foreign_key "role_permissions", "roles", on_delete: :cascade
  add_foreign_key "user_roles", "roles", on_delete: :cascade
  add_foreign_key "user_roles", "users", on_delete: :cascade
end
