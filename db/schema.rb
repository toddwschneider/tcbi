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

ActiveRecord::Schema.define(version: 20141116133717) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "techcrunch_articles", force: true do |t|
    t.string   "title",         limit: 2000
    t.string   "url",           limit: 2000
    t.string   "tag"
    t.string   "author"
    t.datetime "published_at"
    t.string   "story_type"
    t.string   "round"
    t.float    "amount"
    t.float    "dollar_amount"
    t.float    "valuation"
    t.string   "currency"
    t.boolean  "mentions_ipo"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "techcrunch_articles", ["story_type"], name: "index_tc_articles_on_type_and_date", using: :btree
  add_index "techcrunch_articles", ["url"], name: "index_techcrunch_articles_on_url", unique: true, using: :btree

end
