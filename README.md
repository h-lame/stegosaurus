# Stegosaurus

Dinosaurs are cool.  Secrets are cool.  Secret Dinosaurs
would be cooler.  Alas, Jurassic Park style shenanigans
are out of the scope of mere software, but we'll see what
we can do with the idea in the interim.

## Usage

Uh, well...

    irb> require 'lib/stegosaurus'
    irb> w = Stegosaurus.waves(:mono)
    irb> w.make_from('README')

Then go play README.wav in your favourite sound tool.  Yeah
a larger file would totally be more interesting.  But would
it be as secret?

Or...

    irb> require 'lib/stegosaurus'
    irb> b = Stegosaurus.bumps
    irb> b.make_from('README')

Then go look at README.bmp with a seeing device.  Mmm, isn't
that pretty?

Even...

    irb> require 'lib/stegosaurus'
    irb> m = Stegosaurus.midriffs
    irb> m.make_from('README')

Then go play README.mid with your sound tool.  Yeah, it's empty
perhaps a larger file would do something.  Like generate a 12 hour
song with mostly no notes in it?  Yeah, nothings perfect.  What
do you want, a tool to hide data, or a tool to transform it?
Well?  WELL?

Oh, yeah, no-one's reading this.

Sorry.

---

(c) 2008 Murray Steele, [MIT License](./LICENSE).
