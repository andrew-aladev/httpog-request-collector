#!/usr/bin/env ruby

require_relative "../common/colorize"
require_relative "../common/list"
require_relative "../common/requests"
require_relative "requests"

valid_log_urls_path                = ARGV[0]
invalid_log_urls_path              = ARGV[1]
requests_with_special_symbols_path = ARGV[2]

valid_log_urls                = read_list     valid_log_urls_path
invalid_log_urls              = read_list     invalid_log_urls_path
requests_with_special_symbols = read_requests requests_with_special_symbols_path

text = colorize_length invalid_log_urls.length
warn "-- processing #{text} invalid log urls"

begin
  process_requests invalid_log_urls, valid_log_urls, [], requests_with_special_symbols
ensure
  # You can stop processing at any time and it will sync all results.

  write_list     valid_log_urls_path,                valid_log_urls.sort.uniq
  write_list     invalid_log_urls_path,              (invalid_log_urls - valid_log_urls).sort.uniq
  write_requests requests_with_special_symbols_path, requests_with_special_symbols
end
