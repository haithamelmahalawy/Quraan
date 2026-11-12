/// The kinds of «الوقف على الهمز», by the guide of al-Ashab (أصول الأصحاب من
/// الشاطبية والدرة، ص3–7), for Hamza and for Hisham with him in the final
/// hamza: the same divisions for every reader of the chapter.
library;

/// The kinds, in the order they are told: the article, the separated sakin,
/// then the hamza by what it is and what is before it.
const waqfHamzaKinds = [
  'الوقف على لام التعريف',
  'الوقف على الساكن المفصول',
  'الوقف على «شيء» و«شيئًا»',
  'الهمز الساكن',
  'الهمز المتحرك بعد ساكن صحيح',
  'الهمز المتوسط بعد ألف',
  'الهمز المتطرف بعد ألف',
  'الهمز بعد واو أو ياء ساكنتين',
  'الهمز المتحرك بعد متحرك',
  'الهمز المتوسط بحرف زائد',
];

typedef _Letter = ({String base, String marks});

/// A word's letters, each with its marks, the pause marks aside.
List<_Letter> _letters(String word) => [
  for (final m in RegExp(
    r'([^ً-ٰٟۖ-ۭ])([ً-ٰٟۖ-ۭ]*)',
  ).allMatches(word.replaceAll(RegExp('[ۖ-ۛ]'), '')))
    (base: m[1]!, marks: m[2]!),
];

bool _isHamza(_Letter c) =>
    'ءأإؤئآ'.contains(c.base) || RegExp('[ٕٔ]').hasMatch(c.marks);

String _vowelOf(_Letter c) {
  if (c.base == 'آ') return 'a';
  if (RegExp('[ًَٗ]').hasMatch(c.marks)) return 'a';
  if (RegExp('[ٌُٞ]').hasMatch(c.marks)) return 'u';
  if (RegExp('[ٍِٖ]').hasMatch(c.marks)) return 'i';
  if (c.base == 'إ') return 'i';
  return '';
}

/// The bare letters of a word, each hamza and the article's alif a «ء».
String _bare(List<_Letter> cs) => cs
    .map((x) => _isHamza(x) && x.base != 'ٱ' ? 'ء' : x.base)
    .join()
    .replaceAll(RegExp('[ٱأإؤئآ]'), 'ء')
    .replaceAll('ـ', '');

bool _prefixed(List<_Letter> cs, int k) {
  // Each added letter moved: not the madd of «سُوٓءَ».
  bool added(_Letter x, String of) =>
      // Not one with an alif after it (أَسَٰٓـُٔواْ: the hamza after an alif).
      of.contains(x.base) && _vowelOf(x) != '' && !x.marks.contains('ٰ') ||
      (x.base == 'ه' || x.base == 'ي') && x.marks.contains('ٰ');
  // One letter (بِأَيِّكُمُ), or two: a waw, fa, lam or hamza of the question
  // before another (وَلِأَبَوَيۡهِ، فَبِأَيِّ، أَفَأَمِنَ، لَبِإِمَامٖ), not سَبَإِ nor بَلَٰٓؤُاْ.
  final ok = k == 1
      ? added(cs[0], 'وفبلكسءأ')
      : k == 2 && added(cs[0], 'وفءأل') && added(cs[1], 'وفبلكس');
  return ok && _notRoot(cs);
}

bool _notRoot(List<_Letter> cs) =>
    !RegExp('^(سء|سا|فءاد|فءة|فءت|بءيس|بءس(?!م)|لءلء|كءس)').hasMatch(_bare(cs));

/// The hamza at the letter [k] of [word] made a middle one by a letter added
/// before it: «هيا لكسب الوفاء» (وَأَوۡحَىٰ، هَٰٓأَنتُمۡ). Not «سَأَلَ»، its sin
/// of the root, nor «بَأۡس».
bool waqfHamzaPrefixedAt(String word, int k) => _prefixed(_letters(word), k);

/// The kind of the hamza at the letter [k] of [word], [k] counted as the
/// word's letters with their marks.
String waqfHamzaKindAt(String word, int k) {
  final cs = _letters(word);
  final c = cs[k];
  final before = k > 0 ? cs[k - 1] : null;
  final last = cs.sublist(k + 1).every((x) => x.base == 'ا');
  final bare = _bare(cs);
  if (before == null) return 'الوقف على الساكن المفصول';
  if (before.base == 'ل' &&
      k >= 2 &&
      (cs[k - 2].base == 'ٱ' ||
          cs[k - 2].base == 'ا' ||
          // لِلۡإِيمَٰنِ: the article's alif dropped after the lam (لَلۡأَخِرَةُ too).
          cs[k - 2].base == 'ل' && _vowelOf(cs[k - 2]) != '') &&
      _vowelOf(before) == '') {
    return 'الوقف على لام التعريف';
  }
  if (RegExp('شيء').hasMatch(bare)) return 'الوقف على «شيء» و«شيئًا»';
  if (_vowelOf(c) == '' && c.base != 'آ' && !last) return 'الهمز الساكن';
  if (_prefixed(cs, k)) return 'الهمز المتوسط بحرف زائد';
  if (before.base == 'ا' || before.base == 'آ' || before.marks.contains('ٰ')) {
    return last ? 'الهمز المتطرف بعد ألف' : 'الهمز المتوسط بعد ألف';
  }
  if (_vowelOf(before) == '' || RegExp('[ْۡ]').hasMatch(before.marks)) {
    return const {'و', 'ي', 'ى'}.contains(before.base)
        ? 'الهمز بعد واو أو ياء ساكنتين'
        : 'الهمز المتحرك بعد ساكن صحيح';
  }
  // A final hamza after a moved letter is quiet in the stop (ٱقۡرَأۡ، يَبۡدَؤُاْ).
  return last ? 'الهمز الساكن' : 'الهمز المتحرك بعد متحرك';
}

/// The kind of [word]'s last hamza, read as the stop meets it; null when the
/// word has no hamza after its first letter.
String? waqfHamzaKindOfFinal(String word) {
  final cs = _letters(word);
  for (var k = cs.length - 1; k > 0; k--) {
    if (_isHamza(cs[k])) return waqfHamzaKindAt(word, k);
  }
  return null;
}
