class CreateTechcrunchArticles < ActiveRecord::Migration
  def change
    create_table :techcrunch_articles do |t|
      t.string :title, :limit => 2000
      t.string :url, :limit => 2000
      t.string :tag
      t.string :author
      t.datetime :published_at
      t.string :story_type
      t.string :round
      t.float :amount
      t.float :dollar_amount
      t.float :valuation
      t.string :currency
      t.boolean :mentions_ipo

      t.timestamps
    end

    add_index :techcrunch_articles, :url, :unique => true
    execute "CREATE INDEX index_tc_articles_on_date ON techcrunch_articles (date(published_at))"
    execute "CREATE INDEX index_tc_articles_on_type_and_date ON techcrunch_articles (story_type, date(published_at))"
  end
end
