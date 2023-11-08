# Let us require stuff in lib without saying lib/ all the time
$LOAD_PATH.unshift(File.dirname(__FILE__)).uniq!

require 'stegosaurus/bumps'
require 'stegosaurus/waves'
require 'stegosaurus/midriffs'

module Stegosaurus
  class << self
    [:bumps, :waves, :midriffs].each do |genus|
      define_method genus.to_s do |*args|
        fossilize(Stegosaurus.const_get(genus.to_s.capitalize),args)
      end
    end

    def ql(path)
      `qlmanage -p "#{path}"`
    end

    def open_wave(path)
      `open -a VLC.app "#{path}"`
    end

    def open_bump(path)
      `open -a Acorn.app #{path}`
    end

    def open_midriff(path)
      `open -a MIDITrail.app "#{path}"`
    end
  end

  def self.fossilize(genus, args)
    species = args.first
    if species && species.is_a?(Symbol) && genus.respond_to?(species)
      args.shift
      genus.send(species, *args)
    else
      genus.send(:new, *args)
    end
  end
  private_class_method :fossilize
end
