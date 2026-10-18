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

Layout: the page fills the screen like a printed mushaf: a header line
(surah, juz) above the frame, the 15 lines spread over the height, and a
narrow hamesh whose notes sit level with their lines; notes that do not fit
continue below, and the page then leaves a little room for them. Tap the
page number to go to any page.

Double blink (optional, off by default): with the front camera, ML Kit face
detection reads the eye-open probabilities on the device (nothing is
recorded or sent). Tap a mutashabih to choose it, blink twice to open its
places, and twice again to move to the next place. A phone camera cannot
tell which word the eyes are on, so the target is the tapped mutashabih (or
the first one on the page). Requires the camera permission; iOS 15.5+.

Reading: pages turn like a printed mushaf (drag to lift the sheet; it turns
on its spine with shadows), pinch to zoom the whole page image with its frame (one finger pans
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
- **Line layout:** quran.com API (`line_v2`, `v2_page`, the KFGQPC 1421H
  print). It matches the KFGQPC 1441H text on 525 of 604 pages; the QUL
  "KFGQPC V4 layout (1441H print)" covers the remaining 79 exactly.
- **Online qiraat (12 riwayat):** [Quranpedia](https://quranpedia.net), see below.
- **Mutashabihat:** [Quran Mutashabihat Data](https://github.com/Waqar144/Quran_Mutashabihat_Data)
  by Waqar144 (CC0), based on the work of the late Qari Idrees Al-Asim.

### The other twelve riwayat (online)

Hisham, Ibn Dhakwan, Khalaf, Khallad, Abu al-Harith, al-Duri 'an al-Kisa'i,
Ibn Wardan, Ibn Jammaz, Ruways, Rawh, Ishaq and Idris have no published
digital mushaf text (KFGQPC released only the eight above; the rest exist as
scanned PDFs). They are read from **Quranpedia — الموسوعة القرآنية**
([api.quranpedia.net](https://api.quranpedia.net), `GET /v1/ayah/{s}/{a}/qiraat`),
which lists for each word the reading of all twenty riwayat.
`lib/data/online_qiraat.dart` fetches the ayahs of the page being read (and the
next page), maps each Quranpedia word onto the KFGQPC Hafs words, splits
"(تَدْعُونَ) بالتاء" into the reading and its description, and caches the result on
the device. Quranpedia permits in-app use of its API but not bulk-downloading
and republishing its data, so these readings are not stored in the app's
assets and need an internet connection the first time a page is opened.

### Adding a riwaya offline

To give any riwaya an offline text, put `assets/data/qiraat/<id>.json` in the
format above. The app discovers it from the asset manifest and uses it
instead of the online source; no code change is needed. If the text needs its
own font, add it to `pubspec.yaml` and set `fontFamily` in the catalogue.

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
