# FILE hdr + IMAGE hdr + COLOR table + PIXEL data
# -- FILE hdr --
# TYPE          2bytes = "BM"
# SIZE          4bytes = 14 + 40 + colortable + pixel data (unsigned)
# RESERVED_1    2bytes = 0 (unsigned)
# RESERVED_2    2bytes = 0 (unsigned)
# PIXEL_OFFSET  4bytes = offest to start of pixel data (unsigned)
# -- IMAGE chunk --
# SIZE          4bytes = 40 (unsigned)
# WIDTH         4bytes = width of image (signed)
# HEIGHT        4bytes = height of image (signed)
# PLANES        2bytes = 1 (unsigned)
# BITCOUNT      2bytes = bits per pixel: 1,2,4,8,16,24,32 (unsigned)
#                        NOTE: 16 & 32 mean a weird colour table, don't use them
# COMPRESSION   4bytes = compression type: 0 (unsigned)
# SIZEIMAGE     4bytes = image size: 0 for uncompressed (unsigned)
# X_RESOLUTION  4bytes = preferred pixels per meter (X) (signed)
# Y_RESOLUTION  4bytes = preferred pixels per meter (Y) (signed)
# COLOURS_USED  4bytes = number of used colours (0 for 24bit) (unsigned)
# COLOURS_IMP   4bytes = number of important colours (0 for 24bit) (unsigned)
# -- COLOR table --
# Repeat the following for each colour (e.g. BITCOUNT of 8 = 256 colours)
# Blue          1byte = red value
# Green         1byte = green value
# Red           1byte = blue value
# Unused        1byte = 0
# -- PIXEL data --
# Data          .....
# Scan Lines must be multiples of 4-bytes, so we may have to pad with
# 0,1,2 or 3 null bytes for each line in the file.
# Scan Line = WIDTH * BITCOUNT
# NOTE - data rows are back to front - e.g. first row of data is bottom
# row of picture.

# TODO: some kinda callback registration so we can know what's happening
# during the various steps
require 'stegosaurus/genus'

module Stegosaurus
  class Bumps < Genus
    attr_accessor :bit_count

    def self.valid_colour_depth(colour_depth)
      # bits per pixel: 1,2,4,8,16,24,32
      # NOTE: 16 & 32 mean a weird colour table, don't use them
      bc = colour_depth.to_i
      if [1,2,4,8,24].include? bc
        bc
      elsif bc < 1
        1
      elsif bc == 3
        4
      elsif (bc > 4 && bc < 8)
        8
      elsif (bc > 8 && bc < 24)
        24
      else
        24
      end
    end

    def initialize(colour_depth = 8)
      @colour_depth = Bumps.valid_colour_depth(colour_depth || 8)
    end

    def make_from(file_name)
      file_name = File.expand_path(file_name)
      raise ArgumentError, 'Can\'t make bumps from nothing' unless File.exist?(file_name)

      (pixels, final_pixel_pad_bytes) = pixel_count_from(file_name)
      ((width, height), pad_pixels) = width_and_height_from_pixels(pixels)
      bump_header = make_bump_header(width, height)
      write_genus_file(file_name) do |file_part, bump_file, data_file|
        if file_part == :header
          write_bump_header(bump_file, *bump_header)
        elsif file_part == :data
          write_bump_data(bump_file, data_file, final_pixel_pad_bytes, width, pad_pixels)
        end
      end
    end

    private

    def genus_extension
      'bmp'
    end

    def pixel_count_from(file_name)
      # This function returns the number of pixels that this file
      # would create for the current colour_depth.
      # The return value is a tuple of two items:
      #   1. the pixel count
      #   2. the number of pad bytes that need to be added to the
      #      end of the files data to complete the final pixel.
      # Note, it's only really a problem if the colour_depth is either not
      # a multiple of 8 (which we don't allow) or > 8 (which we only allow
      # in the guise of 24).
      file_size = File.size(file_name)
      file_size_in_bits = file_size * 8
      # NOTE - the divide is ok, we deal with fractions with a modulo if needed
      real_pixels = (file_size_in_bits / @colour_depth)
      if @colour_depth == 24
        pad_for_final_pixel = (file_size_in_bits % 24)
        if pad_for_final_pixel == 0
          [real_pixels, 0]
        else
          # NOTE - again, this divide is ok as we shouldn't ever get non-factor-of-8
          # values.
          [real_pixels + 1, (@colour_depth - pad_for_final_pixel) / 8]
        end
      else
        # NOTE - again, this divide is ok as @colour_depth is already a factor of
        # 8, which we used to generate file_size_in_bits above.
        [real_pixels, 0]
      end
    end

    def width_and_height_from_pixels(pixels)
      # This function returns the width and height of the image given the
      # supplied number of pixels.
      # The return value is a 2 part tuple:
      #     1.  A tuple of (Width, Height) in pixels.
      #     2.  The number of pad pixels that have to be added
      #         to create an image of the returned width and height.
      # The algorithm is to find the square root of the pixel count
      # and if this is not a whole number, we round up and calculate the
      # difference in pixels such that:
      # pad_pixels = square(round_up(sqrt(pixels))) - pixels
      root = Math.sqrt(pixels).ceil
      pad = (root**2) - pixels
      [[root,root],pad]
    end

    def colour_table_size
      if @colour_depth == 24
        0
      else
        colours = 2 ** @colour_depth
        colours * 4
      end
    end

    def scan_line_pad_bits(width)
      spare = ((width * @colour_depth) % 32)
      if spare == 0
        spare
      else
        (32 - spare)
      end
    end

    def make_bump_header(width, height)
      bump_size = 54 # header
      bump_size += colour_table_size # color table
      offset = bump_size

      # calculate size = scan_line_width * height
      # scan_line_width = width rounded up to nearest 4 byte (32 bit) number
      width_in_bits = width * @colour_depth
      width_in_bits_to_nearest_32bit_number = ((width_in_bits + 31) / 32) * 32
      scan_line_width_in_bytes = width_in_bits_to_nearest_32bit_number / 8
      image_size = scan_line_width_in_bytes * height
      bump_size += image_size

      file_header = "BM"
      file_header += [bump_size, 0, 0, offset].pack("Vv2V")

      image_header = [40, width, height, 1, @colour_depth, 0, 0].pack("Vl<2v2V2")
      # I can honestly say that whilst I know what these mean, I don't
      # know if these default values can affect the stored data or not
      image_header += [96, 96].pack('l<2')

      if @colour_depth == 24
        image_header += [0,0].pack('V2')
      else
        image_header += [2**@colour_depth,0].pack('V2')
      end

      colour_table = if @colour_depth == 24
                       nil
                     else
                       get_colour_table
                     end
      [file_header, image_header, colour_table]
    end

    def write_bump_header(bump_file, file_header, image_header, colour_table)
      bump_file.write(file_header)
      bump_file.write(image_header)
      unless colour_table.nil?
        colours = colour_table.flatten
        bump_file.write(colours.pack('c%d' % colours.size))
      end
      bump_file.flush()
    end

    def get_colour_table
      # I'm not super sure how exactly we do this.  I think we might want to use
      # the file data for this, which means we should do nothing here, but
      # change the calculations of stuff to take it into account.
      case @colour_depth
      when 1
        [[0x00,0x00,0x00,0x00], [0xFF,0xFF,0xFF,0x00]] #black and white
      when 2
        [[0x00,0x00,0x00,0x00], [0xFF,0xFF,0xFF,0x00],
         [0x00,0x00,0xFF,0x00], [0xFF,0x00,0x00,0x00]] #black, white, red, blue
      when 4 # standard windows 16-bit colours... CGA?
        [[0x00,0x00,0x00,0x00], [0x00,0x00,0x80,0x00], [0x00,0x80,0x00,0x00], [0x00,0x80,0x80,0x00],
         [0x80,0x00,0x00,0x00], [0x80,0x00,0x80,0x00], [0x80,0x80,0x00,0x00], [0xC0,0xC0,0xC0,0x00],
         [0x80,0x80,0x80,0x00], [0x00,0x00,0xFF,0x00], [0x00,0xFF,0x00,0x00], [0x00,0xFF,0xFF,0x00],
         [0xFF,0x00,0x00,0x00], [0xFF,0x00,0xFF,0x00], [0xFF,0xFF,0x00,0x00], [0xFF,0xFF,0xFF,0x00]]
      when 8
        grid = ((0..7).inject([]) do |rows, row_num|
          row = ((0..7).inject([]) do |row, chunk_num|
            (0..3).inject(row) do |row_again, cell_in_chunk_num|
              row_again << [(0+(36*chunk_num)), (0+(36*row_num)), (0+(85*cell_in_chunk_num)), 0x00]
              row_again
            end
          end)
          rows << row
          rows
        end)
        grid[7][31] = [0xff,0xff,0xff,0x00] # white, not the 0xfc,0xfc,0xff off-white the above will generate
        grid
      when 24
        nil
      end
    end

    def write_bump_data(bump_file, data_file, final_pixel_pad_bytes, width, pad_pixels)
      if @colour_depth % 8 == 0
        write_byte_scale_bump_data(bump_file, data_file, width, final_pixel_pad_bytes, pad_pixels)
      else
        write_bit_scale_bump_data(bump_file, data_file, width)
      end
      bump_file.flush()

      pad_rows = pad_pixels / width
      if pad_rows > 0
        width_in_bits = width * @colour_depth
        width_in_bits_to_nearest_32bit_number = ((width_in_bits + 31) / 32) * 32
        scan_line_width_in_bytes = width_in_bits_to_nearest_32bit_number / 8

        pad_row = [].pack("x%d" % scan_line_width_in_bytes)
        pad_rows.times do
          bump_file.write(pad_row)
        end
      end
    end

    def write_byte_scale_bump_data(bump_file, data_file, width, final_pixel_pad_bytes, pad_pixels)
      line_pad_bytes = scan_line_pad_bits(width) / 8 # this won't be a lossy divide - we know we're byte scale at this point
      line_pad = [].pack("x%d" % line_pad_bytes)
      fetch_size = width

      # write data
      (data, eof) = bytes_from(data_file, fetch_size)
      while not eof
        bump_file.write(data)
        bump_file.write(line_pad)
        (data, eof) = bytes_from(data_file, fetch_size)
      end

      # write last row, if it wasn't complete
      if data.size > 0
        bump_file.write(data)
        bump_file.write([].pack("x%d" % final_pixel_pad_bytes)) if final_pixel_pad_bytes > 0
        bump_file.flush()

        # write final padding
        pad_data_row_pixels = pad_pixels % width
        if pad_data_row_pixels > 0
          last_row_from_data_padding = [].pack("x%d" % ((pad_data_row_pixels * @colour_depth) / 8))
          bump_file.write(last_row_from_data_padding)
        end
        bump_file.write(line_pad)
      end
    end

    def write_bit_scale_bump_data(bump_file, data_file, width)
      bits_needed = width * @colour_depth
      fetch_size = (bits_needed / 8.0).ceil
      line_pad_bits = scan_line_pad_bits(width)

      row = []
      (data, eof) = bytes_from(data_file, fetch_size)
      # write data
      while not eof
        # write a row completely from row if we already have enough in it
        write_bit_scale_scan_line(bump_file, '', row.shift(bits_needed), bits_needed, line_pad_bits) if row.size >= bits_needed


        row = write_bit_scale_scan_line(bump_file, data, row, bits_needed, line_pad_bits)
        (data, eof) = bytes_from(data_file, fetch_size)
      end

      if data.size > 0
        # use up last chunk of data from file
        row = write_bit_scale_scan_line(bump_file, data, row, bits_needed, line_pad_bits)
      end

      if row.size > 0
        # if we didn't completely use up the last chunk of data from the file
        # pad and write out the last row
        write_bit_scale_scan_line(bump_file, '', row, bits_needed, line_pad_bits)
      end
    end

    def write_bit_scale_scan_line(bump_file, data, row, bits_needed, line_pad_bits)
      # turn bytes into bits
      data_as_bits = data.each_byte.map { |x| "%08b" % x }.join.each_char.to_a
      # fill up current row with bits we need for a scanline
      row += data_as_bits.shift(bits_needed - row.size)
      # pad in case we don't have enough in the row already for the pixels
      row += [0] * (bits_needed - row.size)
      # pad the row to scanline scale
      row += [0] * line_pad_bits
      # write the row as bytes
      bump_file.write(row.each_slice(8).map { |x| x.join.to_i(2) }.pack('C*'))
      # return any remaining data unused after the shift
      data_as_bits
    end

    def bytes_from(data_file, how_many_bytes)
      data = ""
      get_size = how_many_bytes
      while (data.size != how_many_bytes)
        chunk = data_file.read(get_size)
        if chunk.nil?
          return [data, true]
        else
          data += chunk
          get_size = how_many_bytes - data.size
        end
      end
      [data, false]
    end
  end
end
