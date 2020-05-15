#!/usr/bin/env ruby

require_relative "../common/format"
require_relative "../common/list"
require_relative "../common/requests"
require_relative "requests"

log_urls_path         = ARGV[0]
valid_log_urls_path   = ARGV[1]
invalid_log_urls_path = ARGV[2]
requests_path         = ARGV[3]

log_urls         = read_list     log_urls_path
valid_log_urls   = read_list     valid_log_urls_path
invalid_log_urls = read_list     invalid_log_urls_path
requests         = read_requests requests_path

log_urls -= valid_log_urls
log_urls -= invalid_log_urls

text = colorize_length log_urls.length
warn "-- processing #{text} log urls"

begin
  process_requests log_urls, valid_log_urls, invalid_log_urls, requests
ensure
  # You can stop processing at any time and it will sync all results.

  write_list     valid_log_urls_path,   valid_log_urls.sort.uniq
  write_list     invalid_log_urls_path, invalid_log_urls.sort.uniq
  write_requests requests_path,         requests
end
