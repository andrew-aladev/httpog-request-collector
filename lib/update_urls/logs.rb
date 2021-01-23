require "addressable/uri"
require "uri"

require_relative "../common/colorize"
require_relative "../common/format"
require_relative "../common/query"

# href='*log*'
# href="*log*"
# href=*log*
PAGE_WITH_LOGS_REGEXP = Regexp.new(
  "
    href[[:space:]]*=[[:space:]]*
    (?:
        '
        (
          [^']*
          log
          [^']*
        )
        '
      |
        \"
        (
          [^\"]*
          log
          [^\"]*
        )
        \"
      |
        (
          [^[:space:]>]*
          log
          [^[:space:]>]*
        )
        [[:space:]>]
    )
  ",
  Regexp::IGNORECASE | Regexp::MULTILINE | Regexp::EXTENDED
)
.freeze

# -r--r--r--  1 257  7070  337967 Jul 29  1992 *log*
LISTING_WITH_LOGS_REGEXP = Regexp.new(
  "
    (
      [^[:space:]]*
      log
      [^[:space:]]*
    )
    (?:
        [[:space:]]
      |
        \\Z
    )
  ",
  Regexp::IGNORECASE | Regexp::MULTILINE | Regexp::EXTENDED
)
.freeze

def get_log_urls_from_page_url(url)
  begin
    uri    = URI url
    scheme = uri.scheme

    case scheme
    when "ftp"
      data, is_listing = get_content_or_listing_from_ftp uri
      regexp           = is_listing ? LISTING_WITH_LOGS_REGEXP : PAGE_WITH_LOGS_REGEXP

    when "http", "https"
      data   = get_http_content uri
      regexp = PAGE_WITH_LOGS_REGEXP

    else
      raise StandardError, "unknown uri scheme: #{scheme}"
    end

  rescue QueryError => query_error
    warn query_error
    return []
  rescue StandardError => error
    warn error
    return nil
  end

  log_urls = data
    .scan(regexp)
    .flatten
    .compact
    .map do |log_url|
      uri    = URI Addressable::URI.parse(url).join(log_url).to_s
      scheme = uri.scheme

      case scheme
      when "ftp", "http", "https"
        uri.to_s
      else
        raise StandardError, "unknown uri scheme: #{scheme}"
      end
    rescue StandardError => error
      warn error
      next nil
    end
    .compact

  return log_urls unless log_urls.empty?

  # Check whether url itself is log url.
  return [url] if url.downcase.include? "log"

  []
end

def get_log_urls(page_urls)
  valid_page_urls   = []
  invalid_page_urls = []
  log_urls          = []

  page_urls
    .shuffle
    .each_with_index do |page_url, index|
      percent = format_percent index, page_urls.length
      warn "- #{percent}% checking page, url: #{page_url}"

      new_log_urls = get_log_urls_from_page_url page_url
      next if new_log_urls.nil?

      if new_log_urls.empty?
        invalid_page_urls << page_url
        page_text = "invalid"
      else
        valid_page_urls << page_url
        page_text = "valid".light_green
      end

      log_text = colorize_length new_log_urls.length
      warn "received #{log_text} log urls, page is #{page_text}"

      log_urls.concat new_log_urls
    end

  valid_page_urls   = valid_page_urls.sort.uniq
  invalid_page_urls = invalid_page_urls.sort.uniq
  log_urls          = log_urls.sort.uniq

  valid_page_text   = colorize_length valid_page_urls.length
  invalid_page_text = colorize_length invalid_page_urls.length
  log_text          = colorize_length log_urls.length
  warn "-- received #{log_text} log urls " \
    "from #{valid_page_text} valid page urls, " \
    "#{invalid_page_text} invalid page urls"

  [valid_page_urls, invalid_page_urls, log_urls]
end
