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
#                   1+ otherwise
# TIME_DIVISION     ticks_per_beat if top bit (0x8000) == 0
#                   frames_per_second if top bit (0x8000) == 1
#                   ticks_per_beat common 48-960
#                   frames_per_second 1st 7 bits (0x7F00) are
#                   SMPTE frames: 24, 25, 29 or 30. Remaining
#                   8 bits (0x00FF) are ticks per frame.
#                   e.g. 0x9978 = frames_per_second,
#                        0x19 (top 7 bits) = 25
#                        0x78 (next 8 bits) = 120
#                        25 frames per second, 120 ticks per
#                        frame

# --- TRACK HDR ---
# CHUNK_ID          4bytes = "MTrk" (0x4D54726B)
# CHUNK_SIZE        4bytes = size of track event data
# TRACK_EVENT_DATA  ongoing...

# --- MIDI EVENTS ---
# DELTA_TIME        variable-length
# EVENT

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
      @buffer_size = 216
      @frames_per_second = Midriffs.valid_frames_per_second(frames_per_second || 25)
      @ticks_per_frame = ticks_per_frame || 120
    end

    def make_from(file_name)
      file_name = File.expand_path(file_name)
      if File.exists?(file_name)
        Tempfile.create(file_name) do |track_file|
          with_data_file(file_name) do |data_file|
            read_from_data_and_write_to_genus(data_file, track_file)
          end
          track_file.flush
          track_file.seek(0)
          file_header, track_header = make_midriff_header(track_file.path)
          write_genus_file(file_name) do |file_part, genus_file, data_file|
            if file_part == :header
              genus_file.write file_header
              genus_file.write track_header
            elsif file_part == :data
              write_raw_data_to_genus(track_file, genus_file)
            end
          end
        end
      end
    end

    protected
      def genus_extension
        'mid'
      end

      def convert_to_variable_length_quantity(value)
        return [0] if value.zero?

        buf = []

        buf << (value & 0x7f)
        while (value >>= 7) > 0
          buf << ((value & 0x7f) | 0x80)
        end

        buf.reverse
      end

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

      def write_midi_events(data)
        # read 27 bytes (pad with 0x0 to get to 27 bytes)
        # split into 8 x 27 bit chunks
        # write each chunk as
        # delta-time-of(xxxxxxxx) 100xxxxx 0xxxxxxx 0xxxxxxx

        fixed = []
        data.each_byte.each_slice(27) do |data|
          padded = data + ([0x0] * (27 - data.size))
          bits = padded.map { |x| "%08b" % x }.join.each_char.to_a

          8.times do
            delta_time = bits.shift(8).join
            on_or_off = bits.shift
            channel = bits.shift(4).join
            note = bits.shift(7).join
            velocity = bits.shift(7).join

            fixed += convert_to_variable_length_quantity(Integer("0b#{delta_time}"))
            fixed << Integer("0b100#{on_or_off}#{channel}")
            fixed << Integer("0b0#{note}")
            fixed << Integer("0b0#{velocity}")
          end
        end

        fixed.pack('C*')
      end
      # filter_data is what genus.rb will use, but write_midi_events is
      # more meaningful for us, so we'll alias it
      alias_method :filter_data, :write_midi_events
  end
end
