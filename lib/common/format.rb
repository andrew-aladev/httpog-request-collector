require "filesize"

FORMAT_PERCENT_ROUND_LENGTH = 2
MAX_STRING_LENGTH           = 100

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

def truncate_string(value, max_length = MAX_STRING_LENGTH)
  if value.length > max_length
    "#{value[0...max_length]}..."
  else
    value
  end
end
