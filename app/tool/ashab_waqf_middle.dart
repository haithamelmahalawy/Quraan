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
    String? kind;
    for (var k = 1; k < cs.length; k++) {
      if (!_isHamza(cs[k])) continue;
      // The final hamza (a silent alif after it aside): Hisham's rows.
      if (cs.sublist(k + 1).every((x) => x.base == 'ا')) continue;
      final f = _middleFaces(w.t, cs, k, khallad);
      if (f.isEmpty) continue;
      faces.add(f);
      kind ??= waqfHamzaKindAt(w.t, k);
    }
    if (faces.isEmpty) continue;
    // Two hamzas of a word: each with its own faces, told hamza by hamza.
    final ways = faces.length == 1 ? faces.single : [_byHamza(faces)];
    put([
      w.s,
      w.a,
      w.w,
      1,
      '',
      'u',
      'وقفًا: ${ways.join('، أو ')}',
      'hisham_waqf',
      {
        'source': ashabSource,
        'stopOnly': true,
        'ways': ways,
        'context': w.t,
        'kind': kind,
        '_parts': faces,
      },
    ]);
    n++;
  }
  return n;
}

/// The faces of the hamza at [k] of the word [cs], not its first letter.
List<String> _middleFaces(String word, List<_Cluster> cs, int k, bool khallad) {
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
      (cs[k - 2].base == 'ٱ' ||
          cs[k - 2].base == 'ا' ||
          // لِلۡإِيمَٰنِ: the article's alif dropped after the lam (لَلۡأَخِرَةُ too).
          cs[k - 2].base == 'ل' && _vowelOf(cs[k - 2]) != '') &&
      _vowelOf(before) == '') {
    // The guide (ص3، ص6): «ولخلاد في الوقف النقل في لام التعريف».
    return khallad ? const ['النقل'] : const ['السكت، وهو المقدّم', 'النقل'];
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
    if (RegExp(r'^((و|ف|ءل|ل|لل|ول)?رءي(ا|اك|ي)|و?تءوي|تءويه)$')
        .hasMatch(bare)) {
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
  if (waqfHamzaPrefixedAt(word, k)) {
    final pv = _vowelOf(before);
    // After the alif of «ها» or «يا» (هَٰٓأَنتُمۡ، يَٰٓـَٔادَمُ): the easing with
    // the madd or the qasr, the two told as one face when Khallad's first.
    if (before.marks.contains('ٰ')) {
      return khallad
          ? ['تسهيلها بين بين مع المد أو القصر، وهو المقدّم', 'التحقيق']
          : [
              'التحقيق، وهو المقدّم',
              'تسهيلها بين بين مع المد',
              'تسهيلها بين بين مع القصر',
            ];
    }
    final ease = vowel == 'a' && pv == 'u'
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
      // A waw or ya of the root (ٱلسُّوٓأَىٰ): the merging first for both
      // narrators (the user, 2026-11-12); the lin, Khallad's merging first.
      return khallad || _asliMadd(bare)
          ? ['$merge، وهو المقدّم', naql]
          : ['$naql، وهو المقدّم', merge];
    }
    // ٱلنَّشۡأَةَ: the naql, and the alif of the rasm, for both narrators (the
    // user, 2026-11-12, over the guide's «دون خلف»).
    return [
      'نقل حركتها إلى الساكن قبلها',
      if (c.base == 'أ') 'إبدالها ألفًا على الرسم',
    ];
  }
  // After a moved letter: the nine forms.
  if (vowel == 'a' && pv == 'u') return const ['إبدالها واوًا مفتوحة'];
  if (vowel == 'a' && pv == 'i') return const ['إبدالها ياءً مفتوحة'];
  final next = k + 1 < cs.length ? cs[k + 1].base : '';
  if (vowel == 'u' && pv == 'i' && next == 'و') {
    // أَنۢبِـُٔونِي، مُسۡتَهۡزِءُونَ: eased, or dropped (the guide); and the
    // ya with its damma, مُسۡتَهۡزِيُونَ (the user, 2026-11-12), though the
    // guide tells al-Dani did not take it, against the rasm.
    return const ['تسهيلها بين بين', 'حذفها', 'إبدالها ياءً مضمومة'];
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
/// عَذَابٌ أَلِيمٌ), when stopping on it: told once, as a rule, not at each
/// word (the user, 2026-11-12). The tahqiq first, by al-Taysir; and the
/// Shatibiyya's additions, Khalaf's sakt and both narrators' naql, which is
/// not after the mim of the plural (لَكُمۡ إِنِّيٓ). On the first such sakin in
/// the mushaf not a mim of the plural, a word with no other hamza.
int _waqfSeparated(String id, List<_Word> words, void Function(List row) put) {
  if (!_hamza.contains(id)) return 0;
  const naql = 'النقل، ما لم يكن الساكن ميم الجمع، فلا نقل فيها';
  final ways = id == 'khallad'
      ? const ['التحقيق، وهو المقدّم', naql]
      : const ['التحقيق، وهو المقدّم', 'السكت', naql];
  final sakinEnd = RegExp(r'(ۡ|[ًࣰٌࣱٍࣲ])([اى]?[ۖ-ۛ]*)$|(ۡ)(ا[ْ۟][ۖ-ۛ]*)$');
  final mimJam = RegExp(r'(ه[ُِ]|ك[ُ]|ت[ُ])مۡ[ۖ-ۛ]*$');
  for (var i = 1; i < words.length; i++) {
    final w = words[i], before = words[i - 1];
    if (before.s != w.s || before.a != w.a) continue;
    if (!RegExp('^[ءأإآ]').hasMatch(w.t)) continue;
    if (sakinEnd.firstMatch(before.t) == null) continue;
    if (mimJam.hasMatch(before.t)) continue;
    if (RegExp('[ءأإؤئٔ]').hasMatch(w.t.substring(1))) continue;
    put([
      w.s,
      w.a,
      w.w,
      1,
      '',
      'u',
      'وقفًا على الساكن المفصول قبل الهمز حيث وقع: ${ways.join('، أو ')}',
      'hisham_waqf',
      {
        'source': ashabSource,
        'stopOnly': true,
        'ways': ways,
        'context': '${before.t} ${w.t}',
        'kind': 'الوقف على الساكن المفصول',
      },
    ]);
    return 1;
  }
  return 0;
}

const _ordinals = ['الأولى', 'الثانية', 'الثالثة'];

/// The faces of a word's hamzas told one by one (the user, 2026-11-12):
/// «الأولى: التحقيق، وهو المقدّم، أو إبدالها ياءً مفتوحة؛ والثانية: …»,
/// then how many faces they make together.
String _byHamza(List<List<String>> parts) {
  final told = [
    for (final (i, p) in parts.indexed) '${_ordinals[i]}: ${p.join('، أو ')}',
  ].join('؛ و');
  // «مع المد أو القصر» is two faces told together.
  int count(List<String> p) =>
      p.fold(0, (n, f) => n + (f.contains('مع المد أو القصر') ? 2 : 1));
  final n = parts.fold(1, (n, p) => n * count(p));
  return n < 2 ? told : '$told؛ فذلك ${_facesCount(n)}';
}

String _facesCount(int n) => switch (n) {
  2 => 'وجهان',
  3 => 'ثلاثة أوجه',
  4 => 'أربعة أوجه',
  5 => 'خمسة أوجه',
  6 => 'ستة أوجه',
  7 => 'سبعة أوجه',
  8 => 'ثمانية أوجه',
  9 => 'تسعة أوجه',
  10 => 'عشرة أوجه',
  11 => 'أحد عشر وجهًا',
  12 => 'اثنا عشر وجهًا',
  13 => 'ثلاثة عشر وجهًا',
  14 => 'أربعة عشر وجهًا',
  15 => 'خمسة عشر وجهًا',
  16 => 'ستة عشر وجهًا',
  18 => 'ثمانية عشر وجهًا',
  20 => 'عشرون وجهًا',
  _ => '${String.fromCharCodes('$n'.codeUnits.map((c) => c + 0x0630))} وجهًا',
};
