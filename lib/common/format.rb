require "filesize"

FORMAT_PERCENT_ROUND_LENGTH = 2
MAX_STRING_LENGTH           = 100

def format_percent(index, length)
  max_index = length - 1
  return "100.00" if max_index.zero?

  percent = index.to_f * 100 / max_index
  format(
    "%.#{FORMAT_PERCENT_ROUND_LENGTH}f",
    percent.round(FORMAT_PERCENT_ROUND_LENGTH)
  )
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
