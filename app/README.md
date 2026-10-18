# مصحف القراءات العشر — Qiraat Mushaf

Flutter app that shows the Madinah mushaf (Hafs, 604 pages, 15 lines per page
as printed) and overlays the differences of any selection of the ten qiraat /
twenty riwayat, with a hamesh, generated Arabic descriptions of each change,
and the verbally similar ayahs (mutashabihat).

## Display modes

| Mode | What you see |
| --- | --- |
| الأصل حفص والخلاف في الهامش (hamesh, default) | Printed Hafs lines; words read differently are coloured by qiraa, and the hamesh beside the page lists who reads them how ("نافع وابن كثير: مَلِكِ بحذف الألف"). Entries that do not fit beside the page continue below it. |
| تلوين المواضع (highlight) | Printed Hafs lines with the words coloured; tap a word for every riwaya's reading. |
| إظهار القراءة بجانب الكلمة (inline) | Flowing Hafs text with each selected reading written small after the word, in the riwaya's own font. |
| عرض النص بالرواية المختارة (replace) | One riwaya selected: the page is rewritten as that riwaya reads it. |

Differences are split into three layers that can be switched on and off:
letters & vowels (farsh), hamza (ibdal / tasheel / naql), and madd, imala,
silah & idgham marks.

Home screen: open the mushaf, or "قراءة الروايات من المصحف": point the
camera at a page of a printed Madinah mushaf, choose the riwayat, and the page
is recognised and opened with them. Recognition runs on the device: Tesseract
(Arabic, tessdata_fast; a local copy of flutter_tesseract_ocr in
third_party/ with a build script for current Android tooling) reads the text,
and lib/data/page_matcher.dart finds the page from the words it reads (bare
letters, rare words and adjacent word pairs weighing more, plus the page
number). Tested: noisy simulated OCR of 80 random pages, and rendered pages
269 and 601 through the full OCR pipeline on Android.

Right or left: when a page opens, an open mushaf briefly shows whether it is
the right (odd) or left (even) page, then shrinks into the small icon by the
page number. Two-page view shows facing pages (odd on the right) and turns a
spread at a time; the hamesh is hidden there.

Layout: the page fills the screen like a printed mushaf: a header line
(surah, juz) above the frame, the 15 lines spread over the height, and a
narrow hamesh whose notes sit level with their lines; notes that do not fit
continue below, and the page then leaves a little room for them. Tap the
page number to go to any page.

Eye control (optional, off by default; front camera, ML Kit face detection
on the device, nothing recorded or sent): wink the left eye for the next
page and the right eye for the previous one; blink three times while looking
at a line to open its mutashabihat, three times again to close them; one
deliberate blink (held a little longer than a natural blink) moves to the
next place. The line looked at is estimated from head pitch and eyelids after
a two-point calibration (first / last line, three blinks each). A setting
swaps the eyes for cameras that report them mirrored. Gesture recognition is
tested in test/eye_gestures_test.dart.

Reading: pages turn like paper (the sheet is pictured and drawn on a bending
strip mesh: it rolls from its free edge over the spine, shaded, its back
showing, with its shadow on the page beneath), pinch to zoom the whole page image with its frame (one finger pans
while zoomed, "حجم الصفحة" resets), full-screen reading without the hamesh, and a
dark (default), light or system appearance. Replace mode keeps the Madinah
pages and lines: every riwaya is shown with the same page and line breaks as
Hafs, the ayahs keeping the Hafs (Kufi) numbering.

Words shared with similar ayahs have a dotted underline; tapping one opens a
carousel of all the places (surah, ayah, page) with the shared words
highlighted, and jumps to any of them.

## Data

| File | Content | Built by |
| --- | --- | --- |
| `assets/data/quran.json` | Hafs text: surahs, and per ayah `[surah, ayah, page, juz, "words"]` | `tool/build_data.dart` |
| `assets/data/qiraat/<riwaya>.json` | `{"riwaya", "font", "variants": [[surah, ayah, word, count, "text", "f/h/u", "description"], ...]}` | `tool/build_data.dart` |
| `assets/data/layout.json` | Lines of each page: surah name, basmala, or the first and last Hafs word | `tool/build_layout.dart` |
| `assets/data/mutashabihat.json` | Groups of similar places with their shared words | `tool/build_mutashabihat.dart` |

Run from `app/`, in this order (the sources are in `../tools/source`):

```
dart run tool/build_data.dart
dart run tool/build_layout.dart
dart run tool/build_mutashabihat.dart
```

### Sources

- **Qiraat texts and fonts:** King Fahd Glorious Quran Printing Complex
  (KFGQPC) Uthmanic texts and fonts, via
  [thetruetruth/quran-data-kfgqpc](https://github.com/thetruetruth/quran-data-kfgqpc):
  Hafs, Shu'bah, Qalun, Warsh, al-Bazzi, Qunbul, al-Duri and al-Susi.
  `build_data.dart` aligns each riwaya against Hafs word by word inside each
  surah (the texts use different ayah counts), compares a normalised form so
  spelling conventions are not reported as differences, and describes each
  difference in Arabic. The descriptions are generated and should be
  reviewed by a specialist.
- **Printed calligraphy:** KFGQPC QCF V2 page fonts (one per page, each word a
  glyph), downloaded once per page from the quran.com CDN and kept on the
  device; glyph codes per word (`code_v2`) in `assets/data/qcf_v2.json`,
  built by `tool/build_layout.dart`. Without the font (offline, first open)
  a page is drawn with the KFGQPC Hafs font. Setting: "خط مصحف المدينة".
- **Line layout:** quran.com API (`line_v2`, `v2_page`, the KFGQPC 1421H
  print). It matches the KFGQPC 1441H text on 525 of 604 pages; the QUL
  "KFGQPC V4 layout (1441H print)" covers the remaining 79 exactly.
- **Qiraat of the other 12 riwayat:** [Quranpedia](https://quranpedia.net) qiraat
  dump, version 2026-10-17, see below.
- **Mutashabihat:** [Quran Mutashabihat Data](https://github.com/Waqar144/Quran_Mutashabihat_Data)
  by Waqar144 (CC0), based on the work of the late Qari Idrees Al-Asim.

### The other twelve riwayat

Hisham, Ibn Dhakwan, Khalaf, Khallad, Abu al-Harith, al-Duri 'an al-Kisa'i,
Ibn Wardan, Ibn Jammaz, Ruways, Rawh, Ishaq and Idris have no published
digital mushaf text (KFGQPC released only the eight above; the rest exist as
scanned PDFs). Their readings come from **Quranpedia — الموسوعة القرآنية**,
whose official qiraat dump ([quranpedia.net/dumps](https://quranpedia.net/dumps),
`qiraat.json.gz`) lists for each word the reading of all twenty riwayat. Its
[licence](https://quranpedia.net/dumps/LICENSE.md) allows use inside apps; a
republished copy credits Quranpedia.net and states the dump version, which is
written into each generated file and shown in the app's sources note.

```
curl -LO https://quranpedia.net/dumps/qiraat.json.gz
dart run tool/build_quranpedia.dart qiraat.json.gz
```

`tool/build_quranpedia.dart` (with `lib/data/quranpedia_qiraat.dart`) maps
each Quranpedia word onto the KFGQPC Hafs words — tolerating the silah marks
and alef spellings of the two texts, and splitting a reading across two ayahs
(الرَّحِيمِ مَلِكِ → مَلِكِ on مَٰلِكِ of 1:4) — splits "(تَدْعُونَ) بالتاء" into the
reading and its description, and writes `assets/data/qiraat/<id>.json`. It
lists the few words it places in a neighbouring ayah and those it cannot place
(mostly entries the dump files under the wrong ayah, e.g. 37:134, 101:6,
102:3). Quranpedia keeps correcting its data: rebuild from a newer dump to take
the corrections in.

### Adding a riwaya

To add or replace a riwaya's text, put `assets/data/qiraat/<id>.json` in the
format above. The app discovers it from the asset manifest; no code change is
needed. If the text needs its own font, add it to `pubspec.yaml` and set
`fontFamily` in the catalogue.

## Tests

`flutter test` checks the data (604 pages, 6236 ayahs, known variants and
descriptions, mutashabihat) and renders pages to `test/goldens/` (tag
`golden`; CI runs `flutter test --exclude-tags golden`).

## iPhone builds (GitHub Actions)

`.github/workflows/ios.yml` runs on every push to `main` and on demand
(Actions → iOS → Run workflow) on a macOS runner:

- **Without signing secrets** it builds an unsigned `.ipa` (artifact
  `ios-unsigned`). Install it on your iPhone with a free Apple ID using
  [Sideloadly](https://sideloadly.io) or AltStore; free-account installs
  expire after 7 days.
- **With signing secrets** it signs the app and uploads it to TestFlight;
  install it from the TestFlight app. This needs an Apple Developer Program
  membership and an app record in App Store Connect with the bundle id
  `sa.nodetech.qiraatMushaf`. Add these repository secrets
  (Settings → Secrets and variables → Actions):

  | Secret | Where to get it |
  | --- | --- |
  | `APPLE_TEAM_ID` | developer.apple.com → Membership details |
  | `ASC_KEY_ID`, `ASC_ISSUER_ID` | App Store Connect → Users and Access → Integrations → App Store Connect API (key with Admin role) |
  | `ASC_KEY_P8_BASE64` | the downloaded `AuthKey_XXXX.p8`, base64-encoded (`base64 -i AuthKey_XXXX.p8`) |
