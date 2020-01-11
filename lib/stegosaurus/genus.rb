module Stegosaurus
  class Genus
    attr_accessor :buffer_size

    def initialize
      @buffer_size = 128
    end

    def genus_file_name_from(file_name, a_genus_extension = nil)
      genus_file_name = "%s.%s" % [file_name, a_genus_extension || genus_extension]
      if File.exists?(genus_file_name)
        (1..999).each do |i|
          genus_file_name = "%s%03d.%s" % [file_name, i, genus_extension]
          return genus_file_name unless File.exists?(genus_file_name)
        end
        raise "Too many #{genus_extension} files already for this file :(  Seriously, that's weird though, what are you doing?"
      else
        genus_file_name
      end
    end
    
    def write_genus_file(data_file_name, *args)
      genus_file_name = genus_file_name_from(data_file_name)
      File.open(genus_file_name, 'w+b') do |genus_file|
        if block_given?
          yield :header, genus_file, nil, *args
        else
          args.each do |header|
            genus_file.write header
          end
        end
        genus_file.flush
        
        File.open(data_file_name, 'r') do |data_file|
          if block_given?
            yield :data, genus_file, data_file, *args
          else
            if self.respond_to?(:filter_data)
              while (d = data_file.read @buffer_size)
                genus_file.write filter_data(d)
              end
            else
              while (d = data_file.read @buffer_size)
                genus_file.write d
              end
            end
          end
        end
        genus_file.flush
      end
      genus_file_name
    end

  end
end
