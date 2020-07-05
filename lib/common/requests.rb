require "set"

require_relative "list"

REQUEST_URI_REGULAR_CHARS = [
  # RFC 3986 - 2.3 Unreserved Characters.
  *("0".."9"),
  *("a".."z"),
  *("A".."Z"),

  # RFC 3986 - 2.2 Reserved Characters.
  ":",
  "/",
  "?",
  "#",
  "[",
  "]",
  "@",

  # RFC 3986 - 2.2 Reserved Characters.
  "!",
  "$",
  "&",
  "\'",
  "(",
  ")",
  "*",
  "+",
  ",",
  ";",
  "=",

  # RFC 3986 - 2.3 Unreserved Characters.
  "-",
  ".",
  "_",
  "~",

  # RFC 3986 - 2.1 Percent-Encoding.
  "%"
]
.to_set
.freeze

REQUEST_SEPARATOR = " ".freeze

def read_requests(file_path)
  read_list(file_path)
    .map do |text|
      data = text.split REQUEST_SEPARATOR
      next nil if data.length != 2

      {
        :log_url => data[0],
        :uri     => data[1]
      }
    end
    .compact
end

def write_requests(file_path, requests)
  data = requests.map do |request|
    request[:log_url] + REQUEST_SEPARATOR + request[:uri]
  end

  write_list file_path, data.sort.uniq
end
