# BIG ENDIAN data
# --- FILE HDR ---
# CHUNK_ID         4bytes = "MThd" (0x4D546864)
# CHUNK_SIZE       4bytes = 6 (0x00000006)
# FORMAT_TYPE      2bytes = 0 - 2
# NUMBER_OF_TRACKS 2bytes = 1 - 65,535
# TIME_DIVISION    2bytes = see following text

# FORMAT_TYPE       0 - 1 track with everything
#                   1 - 2 or more tracks, track 1 = song info, 
#                       tracks 2+ individual tracks
#                   2 - multiple tracks, each self contained not 
#                       neccessarily playable simultaneously
# NUMBER_OF_TRACKS  1 if FORMAT_TYPE=0, 
#                   1+ otherwise
# TIME_DIVISION     ticks_per_beat if top bit (0x8000) == 0
#                   frames_per_second if top bit (0x8000) == 1
#                   ticks_per_beat common 48-960
#                   frames_per_second 1st 7 bits (0x7F00) are 
#                   SMPTE frames: 24, 25, 29 or 30. Remaining 
#                   8 bits (0x00FF) are ticks per frame.
#                   e.g. 0x9978 = frames_per_second,
#                        0x19 (top 7 bits) = 25
#                        0x78 (next 8 bits) = 120
#                        25 frames per second, 120 ticks per
#                        frame

# --- TRACK HDR ---
# CHUNK_ID          4bytes = "MTrk" (0x4D54726B)
# CHUNK_SIZE        4bytes = size of track event data
# TRACK_EVENT_DATA  ongoing...

# --- MIDI EVENTS ---
# DELTA_TIME        variable-length
# EVENT             


# Might be useful if we ever want to write delta-time events, 
# rather than just append the data to the end of the file.
#
# def write_var_len(value)
#   buffer = [nil,nil,nil,nil]
#   
#   count = 0
#   
#   while value >= 128
#     this_bit = ((value & 0x7f) | 0x80)
#     buffer[count] = this_bit
#     count += 1
#     value = value >> 7
#   end
#   buffer[count] = value
#   count += 1
#   buffer.compact.pack('C%d' % count)
# end
require 'stegosaurus/genus'

module Stegosaurus
  class Midriffs < Genus
    attr_accessor :frames_per_second, :ticks_per_frame
  
    def self.valid_frames_per_second(frames_per_second)
      fps = frames_per_second.to_i
      if [24, 25, 29, 30].include? fps
        fps
      elsif fps < 24
        24
      elsif fps > 30
        30
      else
        25
      end
    end
    
    def initialize(frames_per_second = 25, ticks_per_frame = 120)
      @buffer_size = 128
      @frames_per_second = Midriffs.valid_frames_per_second(frames_per_second || 25)
      @ticks_per_frame = ticks_per_frame || 120
    end
  
    def make_from(file_name)
      file_name = File.expand_path(file_name)
      if File.exists?(file_name)
        midriff_header = make_midriff_header(file_name)
        midriff_file_name = genus_file_name_from(file_name, 'mid')
        write_midriff_file(midriff_file_name, midriff_header, file_name)
      end
    end
  
    protected
      def time_division_as_data
        (@ticks_per_frame | (@frames_per_second << 8) | (1 << 15))
      end
  
      def make_midriff_header(file_name)
        file_header = "MThd"
        file_header << [6,0,1,time_division_as_data].pack('Nnnn')
      
        track_header = "MTrk"
        track_header << [File.size(file_name)].pack('N')
      
        [file_header, track_header]
      end

      def write_midriff_file(midriff_file_name, header, data_file_name)
        file_header, track_header = header
        File.open(midriff_file_name, 'w+b') do |midriff|
          midriff.write(file_header)
          midriff.write(track_header)
          midriff.flush()
        
          File.open(data_file_name, 'rb') do |data|
            while (d = data.read @buffer_size)
              d = check_data_for_sysevent(d)
              midriff.write d
            end
          end
          midriff.flush
        end
      end
    
      def check_data_for_sysevent(data)
        fixed = ""
        data.each_byte do |b|
          # These bytes could indicate a MIDI event that needs variable length data.
          # Strip them out, until we can think of a better thing to do.
          if [0xff, 0xf0, 0xf7].include?(b)
            fixed << 0x00
          else
            fixed << b
          end
        end
        fixed
      end
  end
end
