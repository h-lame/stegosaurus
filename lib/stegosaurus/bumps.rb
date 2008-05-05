# FILE hdr + IMAGE hdr + COLOR table + PIXEL data
# -- FILE hdr -- 
# TYPE          2bytes = "BM"
# SIZE          4bytes = 14 + 40 + colortable + pixel data
# RESERVED_1    2bytes = 0
# RESERVED_2    2bytes = 0
# PIXEL_OFFSET  4bytes = offest to start of pixel data
# -- IMAGE chunk --
# SIZE          4bytes = 40
# WIDTH         4bytes = width of image
# HEIGHT        4bytes = height of image
# PLANES        2bytes = 1
# BITCOUNT      2bytes = bits per pixel: 1,2,4,8,16,24,32
#                        NOTE: 16 & 32 mean a weird colour table, don't use them
# COMPRESSION   4bytes = compression type: 0
# SIZEIMAGE     4bytes = image size: 0 for uncompressed
# X_RESOLUTION  4bytes = preferred pixels per meter (X)
# Y_RESOLUTION  4bytes = preferred pixels per meter (Y)
# COLOURS_USED  4bytes = number of used colours (0 for 24bit)
# COLOURS_IMP   4bytes = number of important colours (0 for 24bit)
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

# TODO: some kinda callback registration so we can know what's happening
# during the various steps
require 'stegosaurus/genus'

module Stegosaurus
  class Bumps < Genus
    attr_accessor :bit_count
  
    def initialize(bit_count = 8)
      @bit_count = bit_count || 8
    end
  
    def make_from(file_name)
      file_name = File.expand_path(file_name)
      if File.exists?(file_name)
        (pixels, final_pixel_pad_bits) = pixel_count_from(file_name)
        ((width, height), pad_pixels) = width_and_height_from_pixels(pixels)
        line_pad_bits = scan_line_pad(width)
        image_details = [pixels, final_pixel_pad_bits, [width, height], pad_pixels, line_pad_bits]
        bump_header = make_bump_header(image_details)
        bump_file_name = genus_file_name_from(file_name, 'bmp')
        write_bump_file(bump_file_name, image_details, bump_header, file_name)
      end
    end
  
    protected
      def pixel_count_from(file_name)
        # This function returns the number of pixels that this file 
        #    would create for the current bit_count.
        #    The return value is a tuple of two items:
        #        1. the pixel count
        #        2. the number of pad bits that need to be added to the
        #           end of the files data to complete the final pixel.
        if File.exists?(file_name)
          file_size = File.size(file_name)
          file_size_in_bits = file_size * 8
          real_pixels = (file_size_in_bits / @bit_count)
          pad_for_final_pixel = (file_size_in_bits % @bit_count)
          if pad_for_final_pixel == 0
            [real_pixels, 0]
          else
            [real_pixels + 1, (@bit_count - pad_for_final_pixel) / 8]
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
        (32 - ((width * @bit_count) % 32))/8
      end

      def make_bump_header(img_details)
        (pixels, final_pixel_pad_bytes, (width, height), pad_pixles, line_pad_bytes) = img_details
                
        bump_size = 54 # header
        bump_size += colour_table_size # color table
        offset = bump_size
        image_size = (((width * @bit_count) / 8) + line_pad_bytes) * height # pixel data
        bump_size += image_size 
    
        file_header = "BM"
        file_header += [bump_size, 0, 0, offset].pack("Vv2V")
    
        image_header = [40, width, height, 1, @bit_count, 0, 0].pack("V3v2V2")
        # I can honestly say that whilst I know what these mean, I don't
        # know if these default values can affect the stored data or not
        image_header += [96, 96].pack('V2') 

        if @bit_count == 24
          image_header += [0,0].pack('V2')
        else
          image_header += [2**bit_count,0].pack('V2')
        end
    
        if @bit_count == 24
          colour_table = nil
        else
          colourtable = colour_table
        end
        [file_header, image_header, colour_table]
      end

      def write_bump_file(bump_file_name, image_details, header, data_file_name)
        (file_header, image_header, colour_table) = header
        (pixels, final_pixel_pad_bytes, (width, height), pad_pixels, line_pad_bytes) = image_details
      
        File.open(bump_file_name, 'w+b') do |bump_file|
          bump_file.write(file_header)
          bump_file.write(image_header)
          bump_file.write(data_header) unless colour_table.nil?
          bump_file.flush()
        
          File.open(data_file_name,"rb") do |data_file|
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
            bump_file.flush()
          end
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
