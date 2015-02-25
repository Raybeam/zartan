# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150225230711) do

  create_table "proxies", force: :cascade do |t|
    t.string   "host",       null: false
    t.integer  "port",       null: false
    t.integer  "source_id",  null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "proxies", ["deleted_at"], name: "index_proxies_on_deleted_at"
  add_index "proxies", ["host", "port"], name: "index_proxies_on_host_and_port", unique: true
  add_index "proxies", ["source_id"], name: "index_proxies_on_source_id"

  create_table "proxy_performances", force: :cascade do |t|
    t.integer  "proxy_id",                    null: false
    t.integer  "site_id",                     null: false
    t.datetime "reset_at"
    t.datetime "deleted_at"
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
    t.integer  "times_succeeded", default: 0, null: false
    t.integer  "times_failed",    default: 0, null: false
  end

  add_index "proxy_performances", ["deleted_at"], name: "index_proxy_performances_on_deleted_at"
  add_index "proxy_performances", ["proxy_id"], name: "index_proxy_performances_on_proxy_id"
  add_index "proxy_performances", ["site_id"], name: "index_proxy_performances_on_site_id"

  create_table "sites", force: :cascade do |t|
    t.string   "name",       null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "sites", ["deleted_at"], name: "index_sites_on_deleted_at"
  add_index "sites", ["name"], name: "index_sites_on_name", unique: true

  create_table "sources", force: :cascade do |t|
    t.string   "type",                       null: false
    t.string   "name",                       null: false
    t.string   "username"
    t.string   "password"
    t.integer  "max_proxies"
    t.float    "reliability", default: 50.0, null: false
    t.datetime "deleted_at"
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
  end

  add_index "sources", ["deleted_at"], name: "index_sources_on_deleted_at"

end
