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

    def self.valid_bit_count(bit_count)
      # bits per pixel: 1,2,4,8,16,24,32
      # NOTE: 16 & 32 mean a weird colour table, don't use them
      bc = bit_count.to_i
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

    def initialize(bit_count = 8)
      @bit_count = Bumps.valid_bit_count(bit_count || 8)
    end

    def make_from(file_name)
      file_name = File.expand_path(file_name)
      if File.exists?(file_name)
        (pixels, final_pixel_pad_bytes) = pixel_count_from(file_name)
        ((width, height), pad_pixels) = width_and_height_from_pixels(pixels)
        line_pad_bits = scan_line_pad(width)
        image_details = [pixels, final_pixel_pad_bytes, [width, height], pad_pixels, line_pad_bits]
        bump_header = make_bump_header(image_details)
        write_genus_file(file_name, image_details, bump_header) do |file_part, bump_file, data_file, image_details, bump_header|
          if file_part == :header
            write_bump_header(bump_file, *bump_header)
          elsif file_part == :data
            write_bump_data(bump_file, data_file, *image_details)
          end
        end
      end
    end

    protected
      def genus_extension
        'bmp'
      end

      def pixel_count_from(file_name)
        # This function returns the number of pixels that this file
        # would create for the current bit_count.
        # The return value is a tuple of two items:
        #   1. the pixel count
        #   2. the number of pad bytes that need to be added to the
        #      end of the files data to complete the final pixel.
        # Note, it's only really a problem if the bit_count is either not
        # a multiple of 8 (which we don't allow) or > 8 (which we only allow
        # in the guise of 24).
        if File.exists?(file_name)
          file_size = File.size(file_name)
          file_size_in_bits = file_size * 8
          # NOTE - the divide is ok, we deal with fractions with a modulo if needed
          real_pixels = (file_size_in_bits / @bit_count)
          if @bit_count == 24
            pad_for_final_pixel = (file_size_in_bits % 24)
            if pad_for_final_pixel == 0
              [real_pixels, 0]
            else
              # NOTE - again, this divide is ok as we shouldn't ever get non-factor-of-8
              # values.
              [real_pixels + 1, (@bit_count - pad_for_final_pixel) / 8]
            end
          else
            # NOTE - again, this divide is ok as we @bit_count is already a factor of
            # 8, which we used to generate file_size_in_bits above.
            [real_pixels, 0]
          end
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
        if @bit_count == 24
          0
        else
          colours = 2 ** @bit_count
          colours * 4
        end
      end

      def scan_line_pad(width)
        spare = ((width * @bit_count) % 32)
        if spare == 0
          spare
        else
          (32 - spare) / 8
        end
      end

      def make_bump_header(img_details)
        (pixels, final_pixel_pad_bytes, (width, height), pad_pixels, line_pad_bytes) = img_details

        bump_size = 54 # header
        bump_size += colour_table_size # color table
        offset = bump_size
        image_size = (((width * @bit_count) / 8) + line_pad_bytes) * height # pixel data
        bump_size += image_size

        file_header = "BM"
        file_header += [bump_size, 0, 0, offset].pack("Vv2V")

        image_header = [40, width, height, 1, @bit_count, 0, 0].pack("Vl<2v2V2")
        # I can honestly say that whilst I know what these mean, I don't
        # know if these default values can affect the stored data or not
        image_header += [96, 96].pack('l<2')

        if @bit_count == 24
          image_header += [0,0].pack('V2')
        else
          image_header += [2**bit_count,0].pack('V2')
        end

        colour_table = if @bit_count == 24
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
        case @bit_count
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

      def write_bump_data(bump_file, data_file, pixels, final_pixel_pad_bytes, dimensions, pad_pixels, line_pad_bytes)
        (width, height) = dimensions
        
        line_pad = [].pack("x%d" % line_pad_bytes)
        fetch_size = (width * @bit_count) / 8 # I hope this is never a *mung* value due to stupid bit_counts...
        # write data
        (data, eof) = bytes_from(data_file, fetch_size)
        while not eof
          bump_file.write(data)
          bump_file.write(line_pad)
          (data, eof) = bytes_from(data_file, fetch_size)
        end
        bump_file.write(data)
        bump_file.write([].pack("x%d" % final_pixel_pad_bytes))
        bump_file.flush()
  
        #write final padding - I'm pretty sure this *could* go mung for a bit_count of less than a byte
        pad_data_row = pad_pixels % width
        data_row = [].pack("x%d" % pad_data_row) + line_pad
        bump_file.write(data_row)
        bump_file.flush()
  
        pad_rows = pad_pixels / width
        pad_row = [].pack("x%d" % ((width * @bit_count) / 8)) + line_pad
        pad_rows.times do
          bump_file.write(pad_row)
        end
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
