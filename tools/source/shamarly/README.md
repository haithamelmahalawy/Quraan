# Shamarly (Egyptian print) layout sources

- `markers.json`: the position of every ayah-end marker on the 522 pages of the
  Shamarly mushaf, as `[page, surah, ayah, x, y]` (pixels of the page image,
  886 px wide; 15 lines about 89.3 px apart, the first at y ≈ 45). Exported
  from the `mushaf` table of `shamerly.db` in
  https://github.com/Mr-DDDAlKilanny/Shamarly (Shamarly Mushaf for Android).
  Rows with ayah 0 mark the openings of pages 2–3.
- `first_word.txt`: for each page, the index of the word it starts with in its
  first ayah (0 when the page starts with a new ayah), posted in
  https://github.com/quran/quran_android/issues/1180.

`app/tool/shamarly/build_shamarly_test.dart` turns them into
`app/assets/data/layout_shamarly.json`.
