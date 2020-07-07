require "net/http"
require "net/ftp"
require "uri"

QUERY_TOR_HOST       = "127.0.0.1".freeze
QUERY_TOR_SOCKS_PORT = 9050
QUERY_TOR_HTTP_PORT  = 8118

QUERY_TOR_SOCKS_SERVER = "#{QUERY_TOR_HOST}:#{QUERY_TOR_SOCKS_PORT}".freeze
QUERY_TOR_SOCKS_PROXY  = "socks://#{QUERY_TOR_SOCKS_SERVER}".freeze
QUERY_TOR_HTTP_PROXY   = "http://#{QUERY_TOR_HOST}:#{QUERY_TOR_HTTP_PORT}".freeze

ENV["SOCKS_SERVER"] = QUERY_TOR_SOCKS_SERVER
ENV["ftp_proxy"]    = QUERY_TOR_SOCKS_PROXY
ENV["https_proxy"]  = ENV["http_proxy"] = QUERY_TOR_HTTP_PROXY

QUERY_TIMEOUT        = 20 # seconds
QUERY_REDIRECT_LIMIT = 5
QUERY_SIZE_LIMIT     = 1 << 30 # 1 GB

QUERY_FTP_LISTING_TERMINATOR = "\n".freeze

class QueryError < StandardError; end

# -- http --

QUERY_HTTP_OPTIONS =
  %i[
    open_timeout
    read_timeout
    write_timeout
    ssl_timeout
    continue_timeout
    keep_alive_timeout
  ]
  .map { |timeout| [timeout, QUERY_TIMEOUT] }
  .to_h
  .freeze

def get_http_content(uri, redirect_limit = QUERY_REDIRECT_LIMIT)
  raise QueryError, "http redirect limit exceeded" if redirect_limit.zero?

  options = QUERY_HTTP_OPTIONS.merge(
    :use_ssl => uri.scheme == "https"
  )

  begin
    response = Net::HTTP.start(uri.host, uri.port, options) do |http|
      path_for_head = uri.path
      path_for_head = "/" if path_for_head.empty?
      head          = http.request_head path_for_head

      content_length = head["content-length"].to_i
      raise QueryError, "size limit exceeded, requested size: #{content_length}" if content_length > QUERY_SIZE_LIMIT

      http.get uri
    end
  rescue QueryError => query_error
    raise query_error
  rescue Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError => http_error
    raise QueryError, "http query failed, error: #{http_error}"
  rescue StandardError => error
    raise StandardError, "http query failed, error: #{error}"
  end

  case response
  when Net::HTTPSuccess
    response.body || ""
  when Net::HTTPRedirection
    next_uri = URI response["location"]
    next_uri = URI.join uri, next_uri if next_uri.relative?
    warn "http redirect to #{next_uri}"

    get_http_content next_uri, redirect_limit - 1
  else
    raise QueryError, "http response failed, code: #{response.code}"
  end
end

def download_http_file(uri, file_path)
  content = get_http_content uri
  File.write file_path, content

  nil
end

# -- ftp --

QUERY_FTP_OPTIONS =
  %i[
    open_timeout
    read_timeout
    ssl_handshake_timeout
  ]
  .map { |timeout| [timeout, QUERY_TIMEOUT] }
  .to_h
  .freeze

def process_ftp(uri, &_block)
  options = QUERY_FTP_OPTIONS.merge(
    :port => uri.port
  )

  begin
    Net::FTP.open(uri.host, options) do |ftp|
      ftp.login
      yield ftp
    end
  rescue QueryError => query_error
    raise query_error
  rescue Net::FTPError => ftp_error
    raise QueryError, "ftp query failed, error: #{ftp_error}"
  rescue StandardError => error
    raise StandardError, "ftp query failed, error: #{error}"
  end
end

def download_file_from_ftp(uri, file_path)
  process_ftp(uri) do |ftp|
    get_file_from_ftp ftp, uri.path, file_path
  end

  nil
end

def get_content_or_listing_from_ftp(uri)
  process_ftp(uri) do |ftp|
    # We don't know whether uri path is file or listing.
    # We can try to get listing for the first time.

    path = uri.path

    begin
      ftp.chdir path
      data = ftp.list.join QUERY_FTP_LISTING_TERMINATOR
      return data, true
    rescue StandardError # rubocop:disable Lint/SuppressedException
    end

    data = get_file_from_ftp ftp, path, nil
    return data, false
  end
end

def get_file_from_ftp(ftp, path, file_path)
  size = ftp.size path
  raise QueryError, "size limit exceeded, requested size: #{size}" if size > QUERY_SIZE_LIMIT

  ftp.getbinaryfile path, file_path
end
