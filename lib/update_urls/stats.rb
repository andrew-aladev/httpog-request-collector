require "json"
require "uri"

require_relative "../common/colorize"
require_relative "../common/query"

STATS_URL = "https://searx.space/data/instances.json".freeze

def get_search_urls
  warn "- processing stats url: #{STATS_URL}"

  begin
    uri  = URI STATS_URL
    data = get_http_content uri
    data = JSON.parse data

    instances   = data["instances"]
    search_urls = [
      instances.keys.map(&:to_s),
      instances.values.flat_map { |instance| instance["alternativeUrls"].keys.map(&:to_s) }
    ]
    .flatten
    .shuffle
    .sort
    .uniq

  rescue StandardError => error
    warn error
    search_urls = []
  end

  search_urls_text = colorize_length search_urls.length
  warn "received #{search_urls_text} search urls"

  search_urls
end
