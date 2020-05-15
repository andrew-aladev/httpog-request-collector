require "colorize"

FORMAT_PERCENT_ROUND_LENGTH = 2

def colorize_length(length)
  length.zero? ? "0" : length.to_s.light_green
end

def format_percent(index, length)
  max_index = length - 1
  return 100 if max_index.zero?

  (index.to_f * 100 / max_index).round FORMAT_PERCENT_ROUND_LENGTH
end
