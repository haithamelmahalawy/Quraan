/// The repeated question (أَءِذَا ... أَءِنَّا): each place's two words and
/// their names in a way's wording. Nafi''s, al-Kisa'i's and Warsh's two ways
/// told at both words in the usul, as Qalun's (the user, 2026-11-14).
library;

/// (surah, first ayah, first word, second ayah, second word, first's name,
/// second's name, the first asked).
const repeatedIstifhamPairs = [
  (13, 5, 4, 5, 7, 'أءذا', 'إنا', true),
  (17, 49, 1, 49, 5, 'أءذا', 'إنا', true),
  (17, 98, 6, 98, 10, 'أءذا', 'إنا', true),
  (23, 82, 1, 82, 6, 'أءذا', 'إنا', true),
  (27, 67, 3, 67, 7, 'إذا', 'أئنا', false),
  (32, 10, 1, 10, 5, 'أءذا', 'إنا', true),
  (37, 16, 0, 16, 5, 'أءذا', 'إنا', true),
  (37, 53, 0, 53, 5, 'أءذا', 'إنا', true),
  (56, 47, 2, 47, 7, 'أئذا', 'إنا', true),
  (79, 10, 1, 11, 0, 'أءنا', 'إذا', true),
];
