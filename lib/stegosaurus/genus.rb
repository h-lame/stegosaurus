module Stegosaurus
  class Genus
    def genus_file_name_from(file_name, genus_extension)
      genus_file_name = "%s.%s" % [file_name, genus_extension]
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
  end
end
