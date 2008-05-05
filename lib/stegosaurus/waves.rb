# RIFF hdr + FMT chunk + DATA chunk
# -- RIFF hdr -- 
# CHUNKID       4bytes = "RIFF"
# CHUNKSIZE     4bytes = 36+data size
# FORMAT        4bytes = "WAVE"
# -- FMT chunk --
# SUBCHUNK1ID   4bytes = "fmt "
# SUBCHUNK1Size 4bytes = 16 (PCM)
# AUDIOFORMAT   2bytes = 1 (PCM)
# NUMCHANNELS   2bytes = 1 (mono), 2 (stereo)
# SAMPLERATE    4bytes = some sample rate
# BYTERATE      4bytes = SAMPLERATE * BLOCKALIGN
# BLOCKALIGN    2bytes = NUMCHANNELS * BITSPERSAMPLE / 8
# BITSPERSAMPLE 2bytes = 8, 16, 32 etc..
# -- DATA chunk --
# SUBCHUNK2ID   4bytes = "data"
# SUBCHUNK2SIZE 4bytes = NUMSAMPLES * NUMCHANNELS * BITSPERSAMPLE / 8
# DATA          ....

# TODO: some kinda callback registration so we can know what's happening
# during the various steps
# 
require 'stegosaurus/genus'

module Stegosaurus
  class Waves < Genus
    attr_accessor :channels, :sample_rate, :bps
  
    def self.mono()
      new(:mono, 22050, 8)
    end
  
    def self.stereo()
      new(:stereo, 22050, 8)
    end
  
    def initialize(channels = :mono, sample_rate = 22050, bps = 8)
      # TODO make sure these values scale to the correct 'shapes'
      @channels = channels || :mono
      @sample_rate = sample_rate || 22050
      @bps = bps || 8
      @buffer_size = 128
    end
  
    def make_from(file_name)
      file_name = File.expand_path(file_name)
      if File.exists?(file_name)
        wave_header = make_wave_header(file_name)
        wave_file_name = genus_file_name_from(file_name, 'wav')
        write_wave_file(wave_file_name, wave_header, file_name)
      end
    end
  
    protected
      def channels_as_data
        case @channels
        when :mono
          1
        when :stereo
          2
        else
          1
        end
      end
  
      def number_of_samples_from(file_name)
        # I dunno, maybe I'll need to pad the file if this is a floaty value?
        (((File.size(file_name) * 8) / channels_as_data.to_f) / @bps.to_f) if File.exists?(file_name)
      end

      def make_wave_header(file_name)
        if File.exists?(file_name)
          file_size = File.size(file_name)
          riff = "RIFF"
          # So .. um .. pack('i') = int.  I want little-endian int and (on my computer at least)
          # 'l' (system endian long), 'N' (network-endian long) and 'i' give the same
          # so I'm assuming that 'V' (little-endian long) is ok. (Probably not for other systems)
          riff << [36 + file_size].pack('V')
          riff << "WAVE"

          fmt = "fmt "

          number_of_samples = number_of_samples_from(file_name)

          block_align = (channels_as_data * @bps) / 8
          byte_rate = @sample_rate * block_align

          fmt << [16, 1, channels_as_data, @sample_rate, byte_rate, block_align, @bps].pack('Vv2V2v2')

          data = 'data'
          # data << [file_size].pack('V')
          data << [(number_of_samples * channels_as_data * @bps) / 8].pack('V')

          [riff, fmt, data]
        else
          nil
        end
      end

      def write_wave_file(wave_file_name, header, data_file_name)
        riff, fmt, data_header = header
        File.open(wave_file_name, 'w+b') do |wave|
          wave.write riff
          wave.write fmt
          wave.write data_header
          wave.flush

          File.open(data_file_name, 'rb') do |data|
            while (d = data.read @buffer_size)
              wave.write d
            end
          end
          wave.flush
        end
      end
  end
end
