require "colorize"
require "filesize"
require "uri"

require_relative "../common/format"
require_relative "../common/query"
require_relative "../common/requests"
require_relative "./archive"

TEMP_DIRECTORY = File.join(File.dirname(__FILE__), "..", "..", "tmp").freeze
LOG_PATH       = File.join(TEMP_DIRECTORY, "log").freeze

# Request: "GET /a/b HTTP/1.0" 200 .
REQUEST_REGEXP = Regexp.new(
  "
    ['\"]
      [^'\"[:space:]]+
      [ ]

      ([^ ]+)
      [ ]

      HTTP/
      (?:
          1\.0
        |
          1\.1
      )
    ['\"]
    [ ]

    [123]
    [0-9]{2}
    [ ]
  ",
  Regexp::MULTILINE | Regexp::EXTENDED
)
.freeze

def download_log(url)
  begin
    uri    = URI url
    scheme = uri.scheme

    case scheme
    when "ftp"
      download_file_from_ftp uri, LOG_PATH
    when "http", "https"
      download_http_file uri, LOG_PATH
    else
      raise StandardError, "unknown uri scheme: #{scheme}"
    end

  rescue StandardError => error
    warn error
    return nil
  end

  LOG_PATH
end

def process_archive(log_url, file_path, requests)
  is_valid        = false
  requests_length = 0

  begin
    ArchiveReader.read_lines(file_path) do |line|
      line
        .scan(REQUEST_REGEXP)
        .compact
        .each do |match|
          next if match.length != 1

          request_uri = match[0]

          unless request_uri.ascii_only?
            warn "request uri: #{request_uri} is not ascii only"
            next
          end

          is_new_request_uri = request_uri.chars.any? { |char| !REQUEST_URI_REGULAR_CHARS.include?(char) }

          if is_new_request_uri
            requests << {
              :request_uri => request_uri,
              :log_url     => log_url
            }
            requests_length += 1
          end

          # We need at least one request.
          is_valid = true
        end
    end

  rescue Archive::Error => error
    warn error
  end

  if is_valid
    warn "log is #{'valid'.light_green}, received #{colorize_length(requests_length)} requests"
  else
    warn "log is invalid"
  end

  [is_valid, requests_length]
end

def process_requests(log_urls, valid_log_urls, invalid_log_urls, requests)
  logs_size = 0

  invalid_log_urls_length = 0
  valid_log_urls_length   = 0
  requests_length         = 0

  log_urls
    .shuffle
    .each_with_index do |log_url, index|
      percent = format_percent index, log_urls.length
      warn "- #{percent}% processing log, url: #{log_url}"

      file_path = download_log log_url
      next if file_path.nil?

      begin
        size = File.size file_path
        warn "downloaded log, size: #{Filesize.new(size).pretty}"

        is_valid, new_requests_length = process_archive log_url, file_path, requests

        if is_valid
          valid_log_urls_length += 1
          valid_log_urls << log_url
        else
          invalid_log_urls_length += 1
          invalid_log_urls << log_url
        end

        requests_length += new_requests_length
        logs_size       += size

      ensure
        File.delete file_path
      end
    end

  logs_size_text = Filesize.new(logs_size).pretty

  invalid_log_urls_text = colorize_length invalid_log_urls_length
  valid_log_urls_text   = colorize_length valid_log_urls_length
  requests_text         = colorize_length requests_length

  warn(
    "-- processed #{logs_size_text} logs size, received " \
    "#{invalid_log_urls_text} invalid logs, " \
    "#{valid_log_urls_text} valid logs, " \
    "#{requests_text} requests"
  )

  nil
end
