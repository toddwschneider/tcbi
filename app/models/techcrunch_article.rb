class TechcrunchArticle < ActiveRecord::Base
  ALLOWED_STORY_TYPES = %w(fundraise acquisition shutdown)

  MIN_FUNDRAISE_AMOUNT = 50_000
  MAX_FUNDRAISE_AMOUNT = 50_000_000_000

  DOLLAR_CONVERSION_RATES = {'$' => 1.0, '€' => 1.3, '£' => 1.6} # these of course change over time, but close enough
  DEFAULT_CURRENCY = '$'
  CURRENCY_SYMBOLS = DOLLAR_CONVERSION_RATES.keys
  ESCAPED_CURRENCY_SYMBOLS = CURRENCY_SYMBOLS.map { |s| Regexp.escape(s) }

  AMOUNT_ABBREVIATIONS = {'k' => 1_000,
                          'thousand' => 1_000,
                          'm' => 1_000_000,
                          'mm' => 1_000_000,
                          'million' => 1_000_000,
                          'b' => 1_000_000_000,
                          'bn' => 1_000_000_000,
                          'billion' => 1_000_000_000}

  AMOUNT_SUFFIXES = AMOUNT_ABBREVIATIONS.keys.sort_by { |s| -s.length }

  AMOUNT_REGEX = %r{
    ~?
    (#{ESCAPED_CURRENCY_SYMBOLS.join("|")})?
    (\d+[\d,\.]*|(?:half\s)?a\s(?:m|b)illion)
    \s?
    (?:(#{AMOUNT_SUFFIXES.join("|")})\b)?
    (?:\+|-plus)?
    (\svaluation)?
  }xi

  FUNDRAISE_REGEX_1 = %r{(?:gets|takes|nabs|injects|lands|announces|scores|secures|pulls\sin|closes).{0,20}?#{AMOUNT_REGEX}\s(?:from|via|led|round|funding|fundraise|in\sfunding|seed|series)}xi
  FUNDRAISE_REGEX_2 = %r{(?:(?<!could\s)raise(?!\.com)|raises|raised|raising).{0,20}?#{AMOUNT_REGEX}}xi
  FUNDRAISE_REGEX_3 = %r{(?:invests|puts).{0,20}?#{AMOUNT_REGEX}(?:\sin|$)}xi
  FUNDRAISE_REGEXES = [FUNDRAISE_REGEX_1, FUNDRAISE_REGEX_2, FUNDRAISE_REGEX_3]

  FUNDRAISE_WITHOUT_AMOUNT_REGEX = %r{
    (?:raises|raising)\s
    (?:(?:an?|more|new|further|another|first|second|major|large)\s)?
    (?:seed|series|angel|cash|money|funding|venture|round|financing|funds|huge\sround|millions|multi-million|\"?six|\"?seven|\"?eight)
  }xi

  FINANCING_ROUND_REGEX = /(\bseed)|series ([a-z])/i

  VALUATION_ADDITIONAL_WORDS = /(?:a|an|of|north of|over|approaching|post|post-money|pre|pre-money|a hefty|around|around a|of up to|near|a near|up to|rumored|a rumored|whopping|a whopping)\s/i
  VALUATION_REGEX = /(?:at|on|gets) #{VALUATION_ADDITIONAL_WORDS}?#{AMOUNT_REGEX} #{VALUATION_ADDITIONAL_WORDS}?valuation|valuation #{VALUATION_ADDITIONAL_WORDS}?#{AMOUNT_REGEX}/i

  IPO_REGEX = /s-1|\bipo\b|initial public offer/i

  ACQUISITION_REGEX = /(?<!not\s)acquired?|acquiring|acquires|acquisition|acqui-?hire/i

  SHUTDOWN_REGEX = /shuts down|(?<!not\s)shutting down|shut\s?down/i

  validates_presence_of :title, :published_at
  validates_inclusion_of :currency, :in => CURRENCY_SYMBOLS, :allow_nil => true
  validates_inclusion_of :story_type, :in => ALLOWED_STORY_TYPES, :allow_nil => true

  after_create :populate_fields

  def populate_fields
    st = extract_story_type
    send("set_#{st}_details") if st.present?
  end

  def extract_story_type
    if FUNDRAISE_REGEXES.any? { |regex| title =~ regex }
      'fundraise'
    elsif title =~ FUNDRAISE_WITHOUT_AMOUNT_REGEX
      'fundraise_without_amount'
    elsif title =~ ACQUISITION_REGEX
      'acquisition'
    elsif title =~ SHUTDOWN_REGEX
      'shutdown'
    end
  end

  class << self
    def populate_all(slice_size = 10_000)
      (1..maximum(:id)).each_slice(slice_size) do |slice|
        populate_id_range(slice.first, slice.last)
      end
    end

    def populate_id_range(lower, upper)
      where("id >= ? AND id <= ?", lower, upper).each(&:populate_fields)
    end
    # handle_asynchronously :populate_id_range
  end

  def set_fundraise_details
    if (details = extract_fundraise_details).present?
      self.story_type = 'fundraise'
      self.currency = details[:currency]
      self.amount = details[:amount]
      self.dollar_amount = details[:dollar_amount]
      self.round = details[:round]
      self.valuation = details[:valuation]
      self.mentions_ipo = details[:mentions_ipo]

      save!
    end
  end

  def set_fundraise_without_amount_details
    self.story_type = 'fundraise'
    save!
  end

  def set_acquisition_details
    self.story_type = 'acquisition'
    save!
  end

  def set_shutdown_details
    self.story_type = 'shutdown'
    save!
  end

  def extract_valuation
    if (vm = title.match(VALUATION_REGEX)).present?
      cap = vm.captures.compact

      cap[1].to_s.gsub(",", "").to_f *
        (AMOUNT_ABBREVIATIONS[cap[2].to_s.downcase] || 1) *
         DOLLAR_CONVERSION_RATES[cap[0] || DEFAULT_CURRENCY]
    end
  end

  def extract_financing_round
    if (fm = title.match(FINANCING_ROUND_REGEX)).present?
      fm.captures.compact.first.to_s.downcase
    end
  end

  def extract_mentions_ipo
    !!(title =~ IPO_REGEX)
  end

  def extract_fundraise_details
    if regex = FUNDRAISE_REGEXES.detect { |r| title =~ r }
      captures = title.match(regex).captures

      if captures[3].to_s.downcase.squish == "valuation"
        currency = nil
        amount = nil
        dollar_amount = nil
      else
        currency = captures[0] || currency_if_no_prefix

        raw_amount = captures[1].to_s.
                                 downcase.
                                 gsub("half a million", "500000").
                                 gsub("a million", "1000000").
                                 gsub("half a billion", "500000000").
                                 gsub("a billion", "1000000000").
                                 gsub(",", "").
                                 to_f

        multiplier = AMOUNT_ABBREVIATIONS[captures[2].to_s.downcase] || 1
        dollar_multiplier = DOLLAR_CONVERSION_RATES[currency] || 1

        amount = raw_amount * multiplier
        dollar_amount = amount * dollar_multiplier
      end

      if amount && (amount < MIN_FUNDRAISE_AMOUNT || amount > MAX_FUNDRAISE_AMOUNT)
        amount = nil
        dollar_amount = nil
      end

      {:currency => currency,
       :amount => amount,
       :dollar_amount => dollar_amount,
       :round => extract_financing_round,
       :valuation => extract_valuation,
       :mentions_ipo => extract_mentions_ipo}
    end
  end

  def currency_if_no_prefix
    if title =~ /\bdollars/i
      '$'
    elsif title =~ /\beur(os)?/i
      '€'
    elsif title =~ /\b(pounds|gbp)/i
      '£'
    else
      DEFAULT_CURRENCY
    end
  end

  class << self
    def create_from_rss
      Feedjira::Feed.fetch_and_parse("http://techcrunch.com/feed/").entries.each do |entry|
        begin
          create do |article|
            article.title = entry.title.to_s.squish.gsub(/[[:space:]]/, ' ')
            article.url = entry.url.to_s.squish.gsub(/\?.+$/, '')
            article.author = entry.author
            article.published_at = entry.published
          end
        rescue ActiveRecord::RecordNotUnique, PG::UniqueViolation
        end
      end
    end

    def scrape_page(page_num)
      url = "http://techcrunch.com/page/#{page_num.to_i}/"

      begin
        html = RestClient.get(url)
      rescue RestClient::ResourceNotFound
        return
      end

      doc = Nokogiri::HTML(html)

      doc.css(".l-main .river li.river-block[id]").each do |elm|
        begin
          create do |article|
            article.title = elm.css(".post-title").inner_text.squish.gsub(/[[:space:]]/, ' ')
            article.url = elm["data-permalink"].presence || elm.css(".post-title a").first.to_h["href"]
            article.tag = elm.css(".tag").map(&:inner_text).join("::")
            article.author = elm.css(".byline a[rel='author']").map(&:inner_text).join("::")
            article.published_at = Time.zone.parse(elm.css(".byline time").first.to_h["datetime"])
            # timezone seems inconsistent, no big deal because we only care about date anyway
          end
        rescue ActiveRecord::RecordNotUnique, PG::UniqueViolation
        end
      end
    end
    # handle_asynchronously :scrape_page, :priority => 12

    def scrape_all(min = 1, max = 6800)
      (min..max).each { |i| scrape_page(i) }
    end

    def running_total(opts = {})
      window_in_days = opts.fetch(:window_in_days, 90).to_i
      start_date = opts.fetch(:start_date, '2005-06-11').to_date
      amount_cutoff = opts.fetch(:amount_cutoff, 150_000_000).to_i

      qry = <<-SQL
        SELECT
          seq.date,
          SUM(COALESCE(data.count, 0)) OVER (ORDER BY seq.date ROWS BETWEEN ? PRECEDING AND CURRENT ROW) AS count90
        FROM
          (SELECT date(d) FROM generate_series(?, date(now()), '1 day'::interval) d) AS seq
            LEFT JOIN
              (SELECT date(published_at) AS date, COUNT(*) AS count
              FROM techcrunch_articles
              WHERE story_type = 'fundraise' AND COALESCE(dollar_amount, 0) < ?
              GROUP BY date) data
            ON seq.date = data.date
        ORDER BY seq.date
      SQL

      find_by_sql([qry, window_in_days - 1, start_date, amount_cutoff]).
        map { |r| [r.date.to_datetime.to_i * 1000, r.count90.to_i] }
    end

    # for some reason there are a bunch of cases of duplicated headlines differing only by capitalization
    # the dupes have urls that end in digits, e.g. -2/, -3/, etc
    def delete_dupes
      qry = <<-SQL
        SELECT date(published_at) AS d, LOWER(title) AS t, COUNT(*)
        FROM techcrunch_articles
        GROUP BY d, t
        HAVING COUNT(*) > 1
      SQL

      find_by_sql(qry).each do |record|
        where("date(published_at) = ? AND LOWER(title) = ?", record.d, record.t).each do |article|
          article.destroy if article.url =~ /-\d\/$/
        end
      end
    end
  end
end
