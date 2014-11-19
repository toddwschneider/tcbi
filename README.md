## The TechCrunch Bubble Index (a.k.a. TCBI)

In support of this post: http://toddwschneider.com/posts/techcrunch-bubble-index

1. Scrapes all historical [TechCrunch](http://techcrunch.com) headlines back to mid-2005
2. Parses TechCrunch's [RSS feed](http://techcrunch.com/feed/) to get new headlines as they're published
3. Uses regular expressions to extract information from each headline
4. Exposes an endpoint that returns a time series of TCBI values (i.e. number of headlines on TechCrunch over past 90 days that specifically relate to startups raising money)

There's also a simple JSON API endpoint available at http://tcbi.toddwschneider.com/data which will return the up-to-date output of `TechcrunchArticle.running_total`
