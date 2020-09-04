require "json"
require "uri"

require_relative "../common/colorize"
require_relative "../common/query"

# We can try to receive all pages from single search url one-by-one.
# But search url will can return 429 error code (too many requests).
# We can make a queue of search urls and process urls one-by-one instead.
# This method provides better results.

# Example search text: "access.log"|"ACCESS_LOG" index|directory.
MAIN_FILES      = %w[ACCESS access].freeze
MAIN_EXTENSIONS = %w[LOG log].freeze

MAIN_TEXTS = MAIN_FILES.flat_map do |file|
  MAIN_EXTENSIONS.flat_map do |extension|
    [
      "#{file}.#{extension}",
      "#{file}_#{extension}"
    ]
  end
end
.freeze

ADDITIONAL_TEXTS = %w[
  archive
  catalog
  catalogue
  data
  directory
  file
  folder
  ftp
  http
  index
  library
  list
  listing
  record
  register
  registry
  repository
  root
  storage
]
.freeze

def get_text
  main_text = MAIN_TEXTS
    .shuffle
    .slice(0, rand(1..MAIN_TEXTS.length))
    .map { |text| "\"#{text}\"" }
    .join("|")

  additional_text = ADDITIONAL_TEXTS
    .shuffle
    .slice(0, rand(0..ADDITIONAL_TEXTS.length))
    .join("|")

  if additional_text.empty?
    main_text
  else
    [main_text, additional_text]
      .shuffle
      .join(" ")
  end
end

def read_new_page_urls_from_search_url(url, text, page_number, page_urls)
  warn "- processing search url: #{url}, text: #{text}, page number: #{page_number}"

  begin
    uri = URI "#{url}/search"
  rescue StandardError
    warn "invalid api url"
    return nil
  end

  params    = { :q => text, :format => "json", :pageno => page_number }
  uri.query = URI.encode_www_form params

  begin
    data = get_http_content uri
  rescue StandardError => error
    warn error
    return nil
  end

  begin
    data = JSON.parse data
  rescue StandardError # Ignoring big error message.
    warn "failed to parse json"
    return nil
  end

  results = data["results"]
  if results.nil?
    warn "can't find results"
    return nil
  end

  new_page_urls = results
    .map { |result| result["url"] }
    .reject { |page_url| page_urls.include? page_url }

  if new_page_urls.empty?
    warn "finished"
    return nil
  end

  new_page_urls_text = colorize_length new_page_urls.length
  warn "received #{new_page_urls_text} page urls"

  new_page_urls
end

def get_page_urls(search_urls)
  page_urls = []

  queue = search_urls
    .shuffle
    .map do |search_url|
      {
        :url         => search_url,
        :text        => get_text,
        :page_number => 1,
        :page_urls   => []
      }
    end

  loop do
    new_queue = []

    queue.each do |data|
      new_page_urls = read_new_page_urls_from_search_url data[:url], data[:text], data[:page_number], data[:page_urls]
      next if new_page_urls.nil?

      data[:page_number] += 1
      data[:page_urls].concat new_page_urls

      page_urls.concat new_page_urls

      new_queue << data
    end

    break if new_queue.empty?

    queue = new_queue
  end

  page_urls = page_urls.sort.uniq

  page_urls_text = colorize_length page_urls.length
  warn "-- received #{page_urls_text} page urls from all search urls"

  page_urls
end
