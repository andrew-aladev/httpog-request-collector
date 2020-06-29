require "filesize"

FORMAT_PERCENT_ROUND_LENGTH = 2

def format_percent(index, length)
  max_index = length - 1
  return 100 if max_index.zero?

  (index.to_f * 100 / max_index)
    .round(FORMAT_PERCENT_ROUND_LENGTH)
    .to_s
end

def format_filesize(size)
  Filesize.new(size).pretty
end
