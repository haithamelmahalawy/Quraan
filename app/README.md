# مصحف القراءات العشر — Qiraat Mushaf

Flutter app that shows the Madinah mushaf (Hafs, 604 pages) and overlays the
differences of any selection of the ten qiraat / twenty riwayat.

## Display modes

| Mode | What you see |
| --- | --- |
| تلوين المواضع (highlight) | Hafs text; every word read differently is coloured by its qiraa (dots when several qiraat differ). Tap a word for every riwaya's reading. |
| إظهار القراءة بجانب الكلمة (inline) | Hafs text with each selected reading written small after the word, in the riwaya's own font. |
| عرض النص بالرواية المختارة (replace) | One riwaya selected: the page is rewritten as that riwaya reads it. |

Differences are split into three layers that can be switched on and off:
letters & vowels (farsh), hamza (ibdal / tasheel / naql), and madd, imala,
silah & idgham marks.

## Data

| File | Content |
| --- | --- |
| `assets/data/quran.json` | Hafs text: surahs, and per ayah `[surah, ayah, page, juz, "words"]` |
| `assets/data/qiraat/<riwaya>.json` | `{"riwaya", "font", "variants": [[surah, ayah, word, count, "text", "f/h/u"], ...]}` |

`word` is the 0-based index of the Hafs word in the ayah and `count` the number
of Hafs words the reading replaces. Riwaya ids are listed in
`lib/models/qiraat_catalog.dart`.

The files are generated from the King Fahd Complex (KFGQPC) Uthmanic texts,
available for Hafs, Shu'bah, Qalun, Warsh, al-Bazzi, Qunbul, al-Duri and al-Susi:

```
dart run tool/build_data.dart ../tools/source
```

The tool aligns each riwaya against Hafs word by word inside each surah (the
texts use different ayah counts) and compares a normalised form, so spelling
conventions (sukun shapes, wasl alef, waqf signs, tanween placement, Maghribi
spellings) are not reported as differences.

### Adding a riwaya

The other twelve riwayat (Hisham, Ibn Dhakwan, Khalaf, Khallad, Abu al-Harith,
al-Duri 'an al-Kisa'i, Ibn Wardan, Ibn Jammaz, Ruways, Rawh, Ishaq, Idris) are
already in the catalogue and appear as "غير متوفرة". To enable one, put
`assets/data/qiraat/<id>.json` in the format above. The app discovers it from
the asset manifest; no code change is needed. If the text needs its own font,
add it to `pubspec.yaml` and set `fontFamily` in the catalogue.

## Tests

`flutter test` checks the data (604 pages, 6236 ayahs, known variants) and
renders pages in each mode to `test/goldens/`.
