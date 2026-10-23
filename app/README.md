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

Warsh's main Quran text is loaded in full from KFGQPC's `warshData_v10.json`,
independently of margin annotations. `dart run tool/build_warsh_text.dart`
aligns it to all 604 Hafs pages and validates every surah without losing,
duplicating or rearranging source letters/vowels. It fixes one joined-word
boundary in the export at 41:51 and ignores silah for anchoring repeated
words. Blank book notes cannot erase a Quran word. Tests verify the actual
word-display callback over all 604 pages, including Maryam and 24:20.
Circled waw/ya signs take the target hamza's place in the page and margin,
anchored to its seat and text baseline at the current text scale. The original
hamza ink is suppressed without removing its seat, vowel or word spacing.
The page number is below the ornament, outside its bottom border, in both
portrait and landscape.

Home screen: open the mushaf, or "قراءة الروايات من المصحف": point the
camera at a page of a printed Madinah mushaf, choose the riwayat, and the page
is recognised and opened with them. Recognition runs on the device: Tesseract
(Arabic, tessdata_fast; a local copy of flutter_tesseract_ocr in
third_party/ with a build script for current Android tooling) reads the text,
and lib/data/page_matcher.dart finds the page from the words it reads (bare
letters, rare words and adjacent word pairs weighing more, plus the page
number). Tested: noisy simulated OCR of 80 random pages, and rendered pages
269 and 601 through the full OCR pipeline on Android.
The scanner first reads a central band (under 40% of the full guide's pixels,
at the same text width), falling back to the full guide if it is inconclusive.
Android sends grayscale bytes directly to a serial OCR worker, preloads Arabic
while the camera opens, and reuses the model without PNG/disk round trips.
Tests cover partial-text matching across all 604 pages, noisy photo OCR,
fallback, camera rotation, concurrent reads and the native-channel contract.
These checks do not measure capture latency on a physical phone.

The home page's people icon opens **القراء العشرة ورواتهم**, an offline
biographical guide. Browse the ten readers or their twenty transmissions,
filter by the reader's or narrator's city and by the seven / complementary
three, and search names. Each reader includes a short biography and expandable
narrator biographies. The guide distinguishes al-Duri's two transmissions
and Khalaf's roles as narrator and tenth reader; its sources are available
from the information button (`lib/data/qurra_biographies.dart`).
The default graph is an organized forest of small 3D trees, grouped by the
reader's city. Each reader sits above his two narrators with local branch
lines. Narrators remain beside their own reader even when their cities differ;
each narrator's city appears below his name. Names stay in separate lanes
during rotation, and shared identities are explained in the biographies.
Scroll to browse all ten readers. Enable the drag-rotation control to orbit,
or use pinch, rotation, zoom, reset and optional automatic-motion controls.
Wide screens balance city groups across columns. Tap a name for its biography
or a city label for its classification. Gold outlines identify the three
complementary readers.
The graph supports full-screen exploration, search, city and seven/three
filters; a list view remains available. Automatic motion respects the device's
reduced-animation setting.

The home library icon opens **المتون ومصادر القراءات**: the complete Shatibiyya
(1,173 couplets), Durrah (240 couplets), and the transcribed readings and proofs
from *التسهيل لقراءات التنزيل*. Poems support chapter selection, Arabic text /
verse-number search, adjustable text size, and the existing per-verse
explanations. Tasheel exposes each indexed note once, with surah, narrator,
section, and text filters; this is a text browser of the transcribed material,
not a PDF viewer. All three sources work offline and leave reader settings
unchanged.

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

After regenerating riwaya files, run `dart run tool/correct_reviewed_farsh.dart`
to retain the reviewed descriptions of **نِعْمَةً** (31:20), Shu'bah's lexical
**تُرْجِئُ** (33:51), and his retained alifs in **الظنونا، الرسولا، السبيلا**
(33:10, 66–67). `tool/build_kharouf.dart` resolves the book's page-427
reference to the alif rule on page 419, and scopes a named reader's stopping
note separately from the other readers sharing a reading. Regression tests
in `test/reading_corrections_test.dart` cover the readings and their margins.
The reviewed corrections also cover Shu'bah's **لؤلؤًا، مرقدنا، ادخلوا،
المنشآت، إنا** on pages 438, 443, 472, 532 and 536. Optional row metadata
`wujuh` preserves the reviewed wording of multiple faces during source
certification. The book builder retains a reader explicitly named alongside
«الباقون», including Shu'bah's second face in **المنشآت**, and gives priority
to the source's preferred face.
Further reviewed Shu'bah notes on pages 543–601 retain both **انشزوا**
faces (kasr first), remove the extra waw description at **نوره، أمره**,
classify **جبريل، من راق، بل ران، مؤصدة** in farsh, mark **سدى** imala
as stopping only and clarify wasl tanween in both **قواريرا** occurrences.
Identical source groups are compared with their vowels and pronunciation
notes intact so **تؤمنون** (69:41), which agrees with Hafs, is not backfilled
as a false difference. `test/shubah_late_pages_test.dart` checks the actual
margins as well as the data and regeneration.

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

### The Shamarly mushaf (Egyptian print)

The pages can follow either the Madinah mushaf (604 pages) or the Shamarly
mushaf (522 pages from page 2, 15 lines), chosen on the start page or in the
reader's bar; the place read carries over. `assets/data/layout_shamarly.json`
is built by `flutter test tool/shamarly/build_shamarly_test.dart` from
`../tools/source/shamarly` (see its README): the page and line of every
ayah-end marker ([Mr-DDDAlKilanny/Shamarly](https://github.com/Mr-DDDAlKilanny/Shamarly))
and the word each page starts with
([quran_android#1180](https://github.com/quran/quran_android/issues/1180)).
Pages, ayah ends and surah headers (two lines, then the basmala) are as
printed; inside an ayah the words are spread over its printed stretch by
their width, so in long ayahs a word at the edge of a line can fall one line
off (pages 4 and 42 checked against the print: most lines exact).

### Recitation rules, the base riwaya, and the Shatibiyya and Durrah

- **Rules applied to the Hafs text** (`dart run tool/build_usul.dart`, after
  the riwayat are built): for Warsh, madd al-badal (shown green, like
  imala), tarqiq of the ra and taghliz of the lam (orange); for Khalaf 'an
  Hamzah, the sakt on ال, شيء and a sakin before a hamza (marked ۜ). The texts
  do not spell these; the tool applies the rules of the Shatibiyya with their
  main exceptions (see its header), so rare words with a ruling of their own
  may differ. Its readings carry their rule as an 8th field. It also drops
  "differences" written exactly as Hafs.
- **Base riwaya:** with several riwayat selected, the riwayat menu chooses the
  one the page shows; its differences from Hafs are coloured, and the others
  are noted only where they differ from it (a riwaya reading as Hafs has no
  note).
- **References:** tapping a Quran word shows the selected readings' evidence
  automatically, using the same Shatibiyya/Durrah cards as a margin note.
  Book citations take priority; matching bayts appear first with expandable
  commentary and the rest of the chapter under "more". If no matching bayt
  is identified, the whole chapter appears immediately. The Durrah covers
  Abu Ja'far, Ya'qub and Khalaf al-'Ashir. Text: Quranpedia's books 127 and 126,
  built by `dart run tool/build_manzumat.dart` into `assets/data/manzumat.json`
  (1173 + 240 verses).

- **Warsh's lin before hamza (al-Azraq):** a sakin waw/ya after fatha and
  before hamza in one word has 4/6 beats in wasl and waqf (Shatibiyya 179–180).
  Maw'ilan and al-maw'udah are marked separately with qasr; sawa'at keeps its
  own lin/badal combinations (bayt 182). These are annotation-only usul rows,
  generated by `tool/build_warsh_usul.dart`; the Quran source text is unchanged.

### Tafsir and recitations

Holding a word (or tapping one without readings) opens its ayah: the
recitation and the tafsir. Both come from Quranpedia's dumps too:

- **Tafsir, offline:** التفسير الميسر، المختصر، السعدي، الجلالين and معاني
  الكلمات (السراج) are in `assets/data/tafsir/<book id>.json.gz` (3.9 MB; a
  text explaining several ayahs is stored once).
- **Tafsir, online:** ابن كثير، الطبري، البغوي، ابن عاشور، الوسيط، زاد المسير،
  المحرر الوجيز، فتح القدير and أضواء البيان are read per ayah from
  `https://api.quranpedia.net/v1/ayah/{s}/{a}/book/{id}` and kept for the
  session (`lib/data/tafsir_repository.dart`).
- **Recitations:** `assets/data/reciters.json` lists, for each of the twenty
  riwayat, the sheikhs recorded ayah by ayah (45 for Hafs, 7 for Warsh, at
  least one for every other riwaya); the ayah streams from
  `<server><sss><aaa>.mp3` (Quranpedia and mp3quran.net), played with
  `just_audio` (`lib/services/ayah_player.dart`). The listener chooses among
  Hafs and the selected riwayat, and the sheikh of each.

```
cd <dumps>; curl -LO https://quranpedia.net/dumps/reciters-index.json.gz
for id in 2012 2003 272 3 2013; do curl -LO https://quranpedia.net/dumps/tafsir-book-$id.json.gz; done
dart run tool/build_tafsir.dart <dumps>
```

### Adding a riwaya

To add or replace a riwaya's text, put `assets/data/qiraat/<id>.json` in the
format above. The app discovers it from the asset manifest; no code change is
needed. If the text needs its own font, add it to `pubspec.yaml` and set
`fontFamily` in the catalogue.

## Tests

Usul examples open the evidence for the clicked rule and its narrators,
including when that narrator is the main displayed reading. Warsh's circled
waw/ya annotations belong to its own text or margin, including the ya face
of two broken hamzas. Vowels follow the circle. Joined hamzat al-wasl is
normalised to the Hafs-style wasl sign without a circle. The Hafs font's
fathatan and stacked dagger-alif/madd anchors are adjusted only for drawing;
the Quran source text remains intact. Israel's foreign-name exception stays
as a margin reminder and does not trigger difference colours or animations.

Warsh's badal is re-evaluated after lexical additions or omissions, and naql
also recognises combining hamzas such as `فَٱلۡـَٰٔنَ` on page 29. Extra ya
readings use their own `ya_zaida` rule and wasl/waqf faces, rather than ha
silah (`tool/correct_ya_zawaid.dart`). Shared nun idgham is not listed as a
Warsh difference. Imala dots are drawn below a letter's own dots in both
the page and margins without modifying the source text.

`tool/build_partitions.dart` builds all 240 quarter boundaries from the
existing Quran.com verse metadata in `tools/source/layout/`. These marks
are independent of the selected reading and available in both editions.
QCF engraved words use one fill pass; the page 22 regression loads a real
QCF font to cover this rendering path without building or launching an APK.

When naql and badal share a letter, badal green takes priority over naql
blue, including the dagger alif of `فَالَٰنَ`. Pure book naql examples do
not create duplicate lexical rows that colour the entire word. Maghribi
`شَئْا` is drawn with a separate hamza carrier so the ya stays visible;
the replacement dot in `يُوَ۬اخِذُكُم` is removed for the Hafs font while
retaining the waw's fatha. These are display conversions; source assets
remain unchanged.

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
