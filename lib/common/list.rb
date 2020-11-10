require "zstds"

LIST_COMPRESS_OPTIONS = {
  :compression_level => ZSTDS::Option::MAX_COMPRESSION_LEVEL
}
.freeze

LIST_ITEM_TERMINATOR = "\n".freeze

def read_list(file_path)
  ZSTDS::String.decompress(File.read(file_path, :mode => "rb"))
    .split(LIST_ITEM_TERMINATOR)
    .map(&:strip)
    .reject(&:empty?)
end

def write_list(file_path, list)
  data = ZSTDS::String.compress list.join(LIST_ITEM_TERMINATOR), LIST_COMPRESS_OPTIONS
  File.write file_path, data, :mode => "wb"

  nil
end
