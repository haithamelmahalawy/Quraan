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
- **Mutashabihat:** [Quran Mutashabihat Data](https://github.com/Waqar144/Quran_Mutashabihat_Data)
  by Waqar144 (CC0), based on the work of the late Qari Idrees Al-Asim.

### Adding a riwaya

The other twelve riwayat (Hisham, Ibn Dhakwan, Khalaf, Khallad, Abu al-Harith,
al-Duri 'an al-Kisa'i, Ibn Wardan, Ibn Jammaz, Ruways, Rawh, Ishaq, Idris) are
already in the catalogue and appear as "غير متوفرة". No open digital text of
them was found (only scanned PDF mushafs). To enable one, put
`assets/data/qiraat/<id>.json` in the format above. The app discovers it from
the asset manifest; no code change is needed. If the text needs its own font,
add it to `pubspec.yaml` and set `fontFamily` in the catalogue.

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
