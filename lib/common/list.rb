require "xz"

LIST_COMPRESS_OPTIONS = {
  :level   => 9,
  :check   => :sha256,
  :extreme => true
}
.freeze

LIST_ITEM_TERMINATOR = "\n".freeze

def read_list(file_path)
  XZ.decompress(File.read(file_path))
    .split(LIST_ITEM_TERMINATOR)
    .map(&:strip)
    .reject(&:empty?)
end

def write_list(file_path, list)
  data = XZ.compress list.join(LIST_ITEM_TERMINATOR), **LIST_COMPRESS_OPTIONS
  File.write file_path, data

  nil
end
