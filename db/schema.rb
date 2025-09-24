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

ActiveRecord::Schema[8.0].define(version: 2025_09_24_204419) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "incident_counters", primary_key: "organization_id", id: :uuid, default: nil, force: :cascade do |t|
    t.integer "last_number", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_incident_counters_on_organization_id"
  end

  create_table "incidents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "title", null: false
    t.text "description"
    t.integer "number", null: false
    t.integer "severity"
    t.integer "status", default: 0, null: false
    t.uuid "slack_creator_id"
    t.uuid "creator_id"
    t.datetime "declared_at", null: false
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_incidents_on_creator_id"
    t.index ["organization_id", "number"], name: "index_incidents_on_organization_id_and_number", unique: true
    t.index ["organization_id"], name: "index_incidents_on_organization_id"
    t.index ["slack_creator_id"], name: "index_incidents_on_slack_creator_id"
    t.check_constraint "resolved_at IS NULL OR resolved_at >= declared_at", name: "resolved_at_after_declared_at"
  end

  create_table "organizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "website_url"
    t.string "logo_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "slack_channels", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "incident_id", null: false
    t.string "slack_channel_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["incident_id"], name: "index_slack_channels_on_incident_id", unique: true
  end

  create_table "slack_installations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "bot_user_id"
    t.text "bot_access_token_ciphertext", null: false
    t.text "signing_secret_ciphertext", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "team_id", null: false
    t.index ["organization_id"], name: "index_slack_installations_on_organization_id", unique: true
    t.index ["team_id"], name: "index_slack_installations_on_team_id", unique: true
  end

  create_table "slack_users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "slack_user_id", null: false
    t.string "display_name"
    t.string "real_name"
    t.string "avatar_url"
    t.uuid "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "slack_user_id"], name: "index_slack_users_on_organization_id_and_slack_user_id", unique: true
    t.index ["organization_id"], name: "index_slack_users_on_organization_id"
    t.index ["user_id"], name: "index_slack_users_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "organization_id", null: false
    t.string "name", null: false
    t.string "email"
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_users_on_organization_id"
  end

  add_foreign_key "incident_counters", "organizations"
  add_foreign_key "incidents", "organizations"
  add_foreign_key "incidents", "slack_users", column: "slack_creator_id"
  add_foreign_key "incidents", "users", column: "creator_id"
  add_foreign_key "slack_channels", "incidents"
  add_foreign_key "slack_installations", "organizations"
  add_foreign_key "slack_users", "organizations"
  add_foreign_key "slack_users", "users"
  add_foreign_key "users", "organizations"
end
