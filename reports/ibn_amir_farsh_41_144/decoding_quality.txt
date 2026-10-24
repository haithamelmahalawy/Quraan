Source decoding and preparation notes

The embedded HQPB fonts use PUA characters and provide no Arabic Unicode map.
The decoder maps their displayed glyphs, keeps physical text lines, and aligns
Hafs consonants to the canonical Quran at the source surah/ayah.

1469 table rows; 1461 exact consonant alignments and
8 reviewed special alignments (cross-ayah joins, prefixes, special hamza).
Zero unmapped legacy glyphs.

There are 41 multi-line Hafs cells and 137 multi-line reading cells.
Among 722 extracted farsh rows, 46 reading cells have multiple lines;
22 have a single Hafs line and multiple reading alternatives. These are NOT
46 new words or 46 independent narrator variants.
Examples: row23 contains two distinct words (ولكن/الشياطين); row525 contains
Hisham/ Ibn Dhakwan forms (هئت/هيت); row737 contains تلقفْ/تلقفُ;
row709 includes wasl/waqf (يا أبتَ / يا أبه), not two wasl readings.

Raw readingFull strings are provenance, not final Quran text. Font ligatures
move vowel marks across constituent glyphs; superscript alifs/ya and Quranic
hamza seats also need normalization. In particular:
- Mika'il: raw double superscript alif; reviewed source override fixes it.
- Ibrahim: preserve the ending case per occurrence and Ibn Dhakwan's HF-first face.
- 52:21: distinguish raised first ذريتهم from accusative second ذريتهم.
- 7:165 بئس, 33:51 ترجئ, and بيوتا cells: glyph geometry had false doubled vowels.
- 37:17 and56:48: source quotes only أو; preserve the rest of أوءاباؤنا.
- Canonical reuse strips imala/taqlil marks belonging only to the other narrator.

The prepared manifest has 721 farsh source rows, one reclassified ha-kinaya
origin (يرضه), and no unresolved rows. It currently proposes 734 rows per narrator.
Automated checks found zero conflicting texts at the same target position
and zero clusters containing contradictory basic vowels. No qiraat JSON is
written by the preparation command.

Reproduction
Install Node dependencies in a tooling directory:
  npm install pdfjs-dist @napi-rs/canvas
From that tooling directory run (paths are positional arguments):
  node <repo>/app/tool/source/ibn_amir/decode_source.mjs <PDF> <repo>/app/assets/data/quran.json <output.json>
Then run:
  node <repo>/app/tool/source/ibn_amir/prepare_decoder_overrides.mjs
  node <repo>/app/tool/build_ibn_amir_farsh.mjs
The decoder uses dependencies resolved from the current working directory.
The source PDF is supplied locally; it is not redistributed in this repository.
