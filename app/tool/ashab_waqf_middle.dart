part of 'build_ashab_usul.dart';

/// A letter of a word and its marks.
typedef _Cluster = ({String base, String marks});

List<_Cluster> _letters(String word) => [
  for (final m in RegExp(
    r'([^ً-ٰٟۖ-ۭ])([ً-ٰٟۖ-ۭ]*)',
  ).allMatches(word.replaceAll(RegExp('[ۖ-ۛ]'), '')))
    (base: m[1]!, marks: m[2]!),
];

bool _isHamza(_Cluster c) =>
    'ءأإؤئآ'.contains(c.base) || RegExp('[ٕٔ]').hasMatch(c.marks);

/// The vowel of a letter: 'a', 'u', 'i', or '' when quiet or unmarked.
String _vowelOf(_Cluster c) {
  if (c.base == 'آ') return 'a';
  if (RegExp('[ًَٗ]').hasMatch(c.marks)) return 'a';
  if (RegExp('[ٌُٞ]').hasMatch(c.marks)) return 'u';
  if (RegExp('[ٍِٖ]').hasMatch(c.marks)) return 'i';
  if (c.base == 'إ') return 'i';
  return '';
}

/// «الوقف على الهمز» of Hamza in the middle of the word, by the guide's
/// divisions, worded as Hisham's rows («وقفًا: إبدالها ألفًا ساكنة»): the
/// quiet hamza made a letter of the vowel before it; the moved one after a
/// sakin moved onto it (النقل), after an alif eased with the madd or the
/// qasr, after a waw or a ya merged or moved; after a moved letter by the
/// nine forms; after a prefix (وَأَوۡحَىٰ، هَٰٓأَنتُمۡ) kept or eased, Khalaf's
/// first face the tahqiq and Khallad's the easing.
int _waqfMiddle(String id, List<_Word> words, void Function(List row) put) {
  if (!_hamza.contains(id)) return 0;
  final khallad = id == 'khallad';
  var n = 0;
  for (final w in words) {
    final cs = _letters(w.t);
    final faces = <List<String>>[];
    for (var k = 1; k < cs.length; k++) {
      if (!_isHamza(cs[k])) continue;
      // The final hamza (a silent alif after it aside): Hisham's rows.
      if (cs.sublist(k + 1).every((x) => x.base == 'ا')) continue;
      final f = _middleFaces(cs, k, khallad);
      if (f.isNotEmpty) faces.add(f);
    }
    if (faces.isEmpty) continue;
    // Two hamzas of a word: each with its own faces.
    String plain(String x) => x.replaceAll('، وهو المقدّم', '');
    final ways = faces.length == 1
        ? faces.single
        : [
            for (final a in faces[0])
              for (final b in faces[1])
                'الأولى: ${plain(a)}، والثانية: ${plain(b)}',
          ];
    put([
      w.s,
      w.a,
      w.w,
      1,
      '',
      'u',
      'وقفًا: ${ways.join('، أو ')}',
      'hisham_waqf',
      {'source': ashabSource, 'stopOnly': true, 'ways': ways, 'context': w.t},
    ]);
    n++;
  }
  return n;
}

const _prefixes = 'وفبلكسءأ';

/// The faces of the hamza at [k] of the word [cs], not its first letter.
List<String> _middleFaces(List<_Cluster> cs, int k, bool khallad) {
  final c = cs[k], before = cs[k - 1];
  final vowel = _vowelOf(c);
  final bare = cs
      .map((x) => _isHamza(x) && x.base != 'ٱ' ? 'ء' : x.base)
      .join()
      .replaceAll(RegExp('[ٱأإؤئآ]'), 'ء')
      .replaceAll('ـ', '');
  const quietMark = '[ْۡ]';
  // After «أل»: the sakt and the naql.
  if (before.base == 'ل' &&
      k >= 2 &&
      (cs[k - 2].base == 'ٱ' || cs[k - 2].base == 'ا') &&
      _vowelOf(before) == '') {
    return khallad
        ? const ['النقل، وهو المقدّم', 'السكت']
        : const ['السكت، وهو المقدّم', 'النقل'];
  }
  // A quiet hamza: the letter of the vowel before it.
  if (vowel == '' && c.base != 'آ') {
    final pv = _vowelOf(before);
    final letter = switch (pv) {
      'u' => 'واوًا',
      'i' => 'ياءً',
      _ => 'ألفًا',
    };
    // وَرِءۡيٗا، ٱلرُّءۡيَا، تُـٔۡوِيٓ، تُـٔۡوِيهِ، رُءۡيَاكَ: merged into the
    // letter after it too.
    // (The article's alif is a hamza in [bare]: ءلرءيا.)
    if (RegExp(r'^((و|ف|ءل|ل|لل|ول)?رءي(ا|اك|ي)|و?تءوي|تءويه)$').hasMatch(bare)) {
      final merged = 'إبدالها $letter وإدغامها فيما بعدها';
      final plain = 'إبدالها $letter ساكنة';
      return khallad
          ? ['$plain، وهو المقدّم', merged]
          : ['$merged، وهو المقدّم', plain];
    }
    // أَنۢبِئۡهُم، وَنَبِّئۡهُمۡ: the ha with the damma or the kasra.
    if (RegExp(r'^و?(ءنب|نب)ءهم$').hasMatch(bare)) {
      const kasr = 'إبدالها ياءً ساكنة مع كسر الهاء';
      const damm = 'إبدالها ياءً ساكنة مع ضم الهاء';
      return khallad ? ['$damm، وهو المقدّم', kasr] : [kasr, damm];
    }
    return ['إبدالها $letter ساكنة'];
  }
  // After a prefix (وَأَوۡحَىٰ، فَأَوَىٰ، بِأَيِّكُمُ، سَأُوْرِيكُمۡ، كَأَنَّهُمۡ،
  // ءَأَنتُمۡ، هَٰٓأَنتُمۡ، يَٰٓـَٔادَمُ): Khalaf's first the tahqiq, Khallad's
  // the easing. Not «سَأَلَ», its sin of the root.
  final prefixed =
      k <= 2 &&
      cs
          .sublist(0, k)
          .every(
            (x) =>
                _prefixes.contains(x.base) ||
                (x.base == 'ه' || x.base == 'ي') && x.marks.contains('ٰ'),
          ) &&
      !RegExp('^(سء|سا|فءاد|فءة|فءت|بءيس|بءس|لءلء|كءس)').hasMatch(bare);
  if (prefixed) {
    final pv = _vowelOf(before);
    final ease = before.marks.contains('ٰ')
        ? 'تسهيلها بين بين مع المد، أو تسهيلها بين بين مع القصر'
        : vowel == 'a' && pv == 'u'
        ? 'إبدالها واوًا مفتوحة'
        : vowel == 'a' && pv == 'i'
        ? 'إبدالها ياءً مفتوحة'
        : 'تسهيلها بين بين';
    return khallad
        ? ['$ease، وهو المقدّم', 'التحقيق']
        : ['التحقيق، وهو المقدّم', ease];
  }
  // After an alif: eased with the madd or the qasr.
  if (before.base == 'ا' || before.marks.contains('ٰ')) {
    return const ['تسهيلها بين بين مع المد', 'تسهيلها بين بين مع القصر'];
  }
  final pv = _vowelOf(before);
  if (pv == '' || RegExp(quietMark).hasMatch(before.marks)) {
    // A waw or a ya of madd (خَطِيٓـَٔةٗ، بَرِيٓـُٔونَ): merged; of lin
    // (سَوۡءَٰتِ، كَهَيۡـَٔةِ، شَيۡـًٔا): moved, or merged.
    if (before.base == 'و' || before.base == 'ي' || before.base == 'ى') {
      // The letter before the waw or ya, a silent alif aside (تَاْيۡـَٔسُواْ).
      var j = k - 2;
      while (j >= 0 && cs[j].base == 'ا' && _vowelOf(cs[j]) == '') {
        j--;
      }
      final lin =
          j >= 0 &&
              _vowelOf(cs[j]) == 'a' &&
              RegExp(quietMark).hasMatch(before.marks) ||
          // A waw or ya of the root (ٱلسُّوٓأَىٰٓ، سِيٓـَٔتۡ).
          _asliMadd(bare);
      const naql = 'نقل حركتها إلى الساكن قبلها';
      const merge = 'إبدالها من جنس ما قبلها وإدغامه فيه';
      if (!lin) return const [merge];
      return khallad
          ? ['$merge، وهو المقدّم', naql]
          : ['$naql، وهو المقدّم', merge];
    }
    // ٱلنَّشۡأَةَ: the naql, and Khallad's alif of the rasm.
    return [
      'نقل حركتها إلى الساكن قبلها',
      if (khallad && c.base == 'أ') 'إبدالها ألفًا على الرسم',
    ];
  }
  // After a moved letter: the nine forms.
  if (vowel == 'a' && pv == 'u') return const ['إبدالها واوًا مفتوحة'];
  if (vowel == 'a' && pv == 'i') return const ['إبدالها ياءً مفتوحة'];
  final next = k + 1 < cs.length ? cs[k + 1].base : '';
  if (vowel == 'u' && pv == 'i' && next == 'و') {
    // أَنۢبِـُٔونِي، مُسۡتَهۡزِءُونَ: eased, or dropped.
    return const ['تسهيلها بين بين', 'حذفها'];
  }
  if (khallad && vowel == 'u' && pv == 'i' && c.base == 'ئ') {
    // سَنُقۡرِئُكَ: al-Akhfash's ya, which the rasm writes.
    return const ['تسهيلها بين بين', 'إبدالها ياءً مضمومة على مذهب الأخفش'];
  }
  return const ['تسهيلها بين بين'];
}

/// A word whose waw or ya before the hamza is of the root, read with the
/// naql too (السوء، سيء، المسيء، السوأى), not an added one (خطيئة، بريء).
bool _asliMadd(String bare) =>
    RegExp(r'(^|[وفبل]|ٱل|ال)(سوء|سيء|مسيء|سيـ?ء)').hasMatch(bare);

/// The hamza of a word after a sakin ending the word before it (مَنۡ ءَامَنَ،
/// عَذَابٌ أَلِيمٌ), when stopping on it: the tahqiq first, by al-Taysir; and
/// the Shatibiyya's additions, Khalaf's sakt and both narrators' naql (the
/// user, 2026-11-12).
int _waqfSeparated(String id, List<_Word> words, void Function(List row) put) {
  if (!_hamza.contains(id)) return 0;
  final ways = id == 'khallad'
      ? const ['التحقيق، وهو المقدّم', 'النقل']
      : const ['التحقيق، وهو المقدّم', 'السكت', 'النقل'];
  final sakinEnd = RegExp(
    r'(ۡ|[ً-ࣰٍ-ࣲ])([اى]?[ۖ-ۛ]*)$|(ۡ)(ا[ْ۟][ۖ-ۛ]*)$',
  );
  var n = 0;
  for (var i = 1; i < words.length; i++) {
    final w = words[i], before = words[i - 1];
    if (before.s != w.s || before.a != w.a) continue;
    if (!RegExp('^[ءأإآ]').hasMatch(w.t)) continue;
    if (sakinEnd.firstMatch(before.t) == null) continue;
    put([
      w.s,
      w.a,
      w.w,
      1,
      '',
      'u',
      'وقفًا على الساكن المفصول قبل الهمز: ${ways.join('، أو ')}',
      'hisham_waqf',
      {
        'source': ashabSource,
        'stopOnly': true,
        'ways': ways,
        'context': '${before.t} ${w.t}',
      },
    ]);
    n++;
  }
  return n;
}
