#!/usr/bin/env ruby

require_relative "../common/format"
require_relative "../common/list"
require_relative "logs"
require_relative "search"
require_relative "stats"

valid_page_urls_path   = ARGV[0]
invalid_page_urls_path = ARGV[1]
log_urls_path          = ARGV[2]

valid_page_urls   = read_list valid_page_urls_path
invalid_page_urls = read_list invalid_page_urls_path
log_urls          = read_list log_urls_path

search_urls = get_search_urls
page_urls   = get_page_urls search_urls

page_urls -= valid_page_urls
page_urls -= invalid_page_urls
page_urls -= log_urls

text = colorize_length page_urls.length
warn "-- processing #{text} page urls"

new_valid_page_urls, new_invalid_page_urls, new_log_urls = get_log_urls page_urls

valid_page_urls   = (valid_page_urls + new_valid_page_urls).sort.uniq
invalid_page_urls = (invalid_page_urls + new_invalid_page_urls).sort.uniq
log_urls          = (log_urls + new_log_urls).sort.uniq

write_list valid_page_urls_path,   valid_page_urls
write_list invalid_page_urls_path, invalid_page_urls
write_list log_urls_path,          log_urls
