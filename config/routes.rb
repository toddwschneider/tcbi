Rails.application.routes.draw do
  root 'techcrunch_articles#redirect'
  get 'data' => 'techcrunch_articles#data'
end
