desc "get articles from RSS"
task :create_articles_from_rss => :environment do
  puts "creating articles from rss"
  TechcrunchArticle.create_from_rss
  puts "done"
end
