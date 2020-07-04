require "uri"

require_relative "../common/colorize"
require_relative "../common/format"
require_relative "../common/query"
require_relative "../common/requests"
require_relative "archive"

TEMP_DIRECTORY = File.join(File.dirname(__FILE__), "..", "..", "tmp").freeze
LOG_PATH       = File.join(TEMP_DIRECTORY, "log").freeze

# Request: "GET /a/b HTTP/1.0" 200 .
# Wrong request to be ignored: "text" 400 .
REQUEST_REGEXP = Regexp.new(
  "
    (?:
        \"
          (?:
              [^\" ]+
              [ ]

              ([^\" ]+)
              [ ]

              HTTP/
              (?:
                  1\.0
                |
                  1\.1
              )
            |
              [^\"]*
          )
        \"
      |
        '
          (?:
              [^' ]+
              [ ]

              ([^' ]+)
              [ ]

              HTTP/
              (?:
                  1\.0
                |
                  1\.1
              )
            |
              [^']*
          )
        '
    )
    [ ]

    [0-9]+
    [ ]
  ",
  Regexp::EXTENDED
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

  rescue QueryError => query_error
    # Query error equal empty log from analysis perspective.
    # So we can simulate that we received empty log.
    warn query_error
    File.write LOG_PATH, ""
  rescue StandardError => error
    warn error
    return nil
  end

  LOG_PATH
end

def process_archive_file(log_url, archive)
  # Validation result is unknown.
  is_valid     = nil
  new_requests = []

  archive.read_lines do |line|
    # We can ignore any line comes after validation result is false.
    next if is_valid == false

    # We can just ignore any empty lines.
    next if line.strip.empty?

    matches = line.scan(REQUEST_REGEXP).compact
    if matches.empty?
      warn "line: #{truncate_string(line)} is invalid"
      is_valid = false
      next
    end

    # Line is valid when all matches are valid.
    is_valid = matches.all? do |match|
      # Match without request uri is possible and can be ignored.
      next true if match.length != 1

      request_uri = match[0]

      unless request_uri.ascii_only?
        warn "request uri: #{request_uri} is not ascii only"
        next false
      end

      is_new_request_uri = request_uri.chars.any? { |char| !REQUEST_URI_REGULAR_CHARS.include?(char) }

      if is_new_request_uri
        new_requests << {
          :request_uri => request_uri,
          :log_url     => log_url
        }
      end

      true
    end
  end

  if is_valid
    [true, new_requests]
  else
    [false, []]
  end
end

def process_archive(log_url, file_path)
  is_valid     = false
  new_requests = []

  begin
    ArchiveReader.open file_path do |archive|
      # Each archive can consist of multiple files.
      until archive.next_header.nil?
        is_file_valid, new_file_requests = process_archive_file log_url, archive

        # Archive is valid when at least one file is valid.
        is_valid = true if is_file_valid
        new_requests.concat new_file_requests
      end
    end

  rescue Archive::Error => error
    warn error
  end

  if is_valid
    requests_text = colorize_length new_requests.length
    warn "log is #{'valid'.light_green}, received #{requests_text} requests"
  else
    warn "log is invalid"
  end

  [is_valid, new_requests]
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
        size      = File.size file_path
        size_text = format_filesize size

        warn "downloaded log, size: #{size_text}"

        is_valid, new_requests = process_archive log_url, file_path

        if is_valid
          valid_log_urls_length += 1
          valid_log_urls << log_url
        else
          invalid_log_urls_length += 1
          invalid_log_urls << log_url
        end

        requests.concat new_requests
        requests_length += new_requests.length
        logs_size       += size

      ensure
        File.delete file_path
      end
    end

  logs_size_text        = format_filesize logs_size
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
