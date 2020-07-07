require "ffi-libarchive"

class ArchiveReader < Archive::BaseArchive
  C      = Archive::C
  Error  = Archive::Error
  Header = Archive::Entry

  BLOCK_SIZE      = 1024
  BUFFER_SIZE     = C::DATA_BUFFER_SIZE
  LINE_TERMINATOR = "\n".freeze

  C.attach_function :archive_read_data, %i[pointer pointer ssize_t], :ssize_t

  def initialize(file_path)
    super C.method(:archive_read_new), C.method(:archive_read_finish)

    if C.archive_read_support_compression_all(archive) != C::OK ||
       C.archive_read_support_format_all(archive) != C::OK ||
       C.archive_read_support_format_raw(archive) != C::OK ||
       C.archive_read_open_filename(archive, file_path, BLOCK_SIZE) != C::OK
      close
      raise Error, @archive
    end
  end

  def next_header
    header_ptr = FFI::MemoryPointer.new :pointer

    case C.archive_read_next_header archive, header_ptr
    when C::OK
      Header.from_pointer header_ptr.read_pointer
    when C::EOF
      @eof = true
      nil
    else
      raise Error, @archive
    end
  end

  def read_data(&_block)
    buffer = FFI::MemoryPointer.new BUFFER_SIZE

    loop do
      length = C.archive_read_data archive, buffer, BUFFER_SIZE

      break if length.zero?
      raise Error, @archive if length.negative?

      yield buffer.get_bytes(0, length)
    end

    nil
  end

  def read_lines(&_block)
    data = String.new :encoding => ::Encoding::BINARY

    read_data do |bytes|
      data << bytes

      loop do
        index = data.index LINE_TERMINATOR
        break if index.nil?

        line = data.byteslice 0, index
        yield line

        next_index = index + LINE_TERMINATOR.bytesize
        data       = data.byteslice next_index, data.bytesize - next_index
      end
    end

    yield data
  end

  def self.open(file_path, &_block)
    archive = new file_path

    begin
      yield archive
    ensure
      archive.close
    end
  end
end
