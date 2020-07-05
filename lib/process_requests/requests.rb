require "uri"

require_relative "../common/colorize"
require_relative "../common/format"
require_relative "../common/query"
require_relative "../common/requests"
require_relative "archive"

TEMP_DIRECTORY = File.join(File.dirname(__FILE__), "..", "..", "tmp").freeze
LOG_PATH       = File.join(TEMP_DIRECTORY, "log").freeze

# Request: "GET /a/b HTTP/1.0" 200 .
# Request: "GET /a/b HTTP/1.0" - .
# Wrong request to be ignored: "text" 400 .
# Wrong request to be ignored: "text" - .
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

    (?:
        [0-9]+
      |
        \-
    )
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

def process_archive_file(archive)
  # Validation result is unknown.
  is_valid     = nil
  request_uris = []

  archive.read_lines do |line|
    # We can ignore any line after validation result became false.
    next if is_valid == false

    # We can just ignore any empty line.
    next if line.strip.empty?

    matches   = line.scan(REQUEST_REGEXP).compact
    line_text = truncate_string line

    is_match_broken = matches.any? { |match| match.length != 2 }
    if is_match_broken
      warn "line: #{line_text} is invalid, it has invalid match"
      is_valid = false
      next
    end

    line_request_uris = matches.map do |match|
      # Request uri equals to first or second match group.
      request_uri =
        if match[0].nil?
          match[1]
        else
          match[0]
        end

      if request_uri.nil?
        warn "line: #{line_text} has match without request uri, ignoring"
        next nil
      end

      unless request_uri.ascii_only?
        warn "line: #{line_text}, request uri: #{request_uri} is not ascii only, ignoring"
        next nil
      end

      request_uri
    end

    if line_request_uris.empty?
      warn "line: #{line_text} is invalid, it provides no request uris"
      is_valid = false
      next
    end

    # Line can be ignored when it has only invalid request uris.
    line_request_uris = line_request_uris.compact
    next if line_request_uris.empty?

    is_valid = true
    request_uris.concat line_request_uris
  end

  if is_valid
    [true, request_uris]
  else
    [false, []]
  end
end

def process_archive(file_path)
  is_valid     = false
  request_uris = []

  begin
    ArchiveReader.open file_path do |archive|
      # Each archive can consist of multiple files.
      until archive.next_header.nil?
        is_file_valid, file_request_uris = process_archive_file archive
        next unless is_file_valid

        # Archive is valid when at least one file is valid.
        is_valid = true
        request_uris.concat file_request_uris
      end
    end

  rescue Archive::Error => error
    warn error
  end

  unless is_valid
    warn "log is invalid"
    return [false, [], []]
  end

  request_uris_with_special_symbols = request_uris.select do |request_uri|
    request_uri.chars.any? { |char| !REQUEST_URI_REGULAR_CHARS.include?(char) }
  end

  request_uris_text                      = colorize_length request_uris.length
  request_uris_with_special_symbols_text = colorize_length request_uris_with_special_symbols.length

  warn "log is #{'valid'.light_green}, " \
    "received #{request_uris_text} request uris, " \
    "received #{request_uris_with_special_symbols_text} request uris with special symbols"

  [true, request_uris, request_uris_with_special_symbols]
end

def process_requests(log_urls, valid_log_urls, invalid_log_urls, requests_with_special_symbols)
  logs_size                                = 0
  invalid_log_urls_length                  = 0
  valid_log_urls_length                    = 0
  request_uris_length                      = 0
  request_uris_with_special_symbols_length = 0

  log_urls
    .shuffle
    .each_with_index do |log_url, index|
      percent = format_percent index, log_urls.length
      warn "- #{percent}% processing log, url: #{log_url}"

      file_path = download_log log_url
      next if file_path.nil?

      begin
        size = File.size file_path

        size_text = format_filesize size
        warn "downloaded log, size: #{size_text}"

        logs_size += size

        is_valid, new_request_uris, new_request_uris_with_special_symbols = process_archive file_path
        if is_valid
          valid_log_urls_length += 1
          valid_log_urls << log_url
        else
          invalid_log_urls_length += 1
          invalid_log_urls << log_url
        end

        request_uris_length                      += new_request_uris.length
        request_uris_with_special_symbols_length += new_request_uris_with_special_symbols.length

        new_request_uris_with_special_symbols.each do |uri|
          requests_with_special_symbols << {
            :log_url => log_url,
            :uri     => uri
          }
        end

      ensure
        File.delete file_path
      end
    end

  logs_size_text                         = format_filesize logs_size
  invalid_log_urls_text                  = colorize_length invalid_log_urls_length
  valid_log_urls_text                    = colorize_length valid_log_urls_length
  request_uris_text                      = colorize_length request_uris_length
  request_uris_with_special_symbols_text = colorize_length request_uris_with_special_symbols_length

  warn(
    "-- processed #{logs_size_text} logs size, received " \
    "#{invalid_log_urls_text} invalid logs, " \
    "#{valid_log_urls_text} valid logs, " \
    "#{request_uris_text} request uris, " \
    "#{request_uris_with_special_symbols_text} request uris with special symbols"
  )

  nil
end
