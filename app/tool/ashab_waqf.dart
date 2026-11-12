part of 'build_ashab_usul.dart';

/// «الوقف على الهمز» of Hamza: the final hamza as Hisham's rows («وَقَفَ
/// هِشَامٌ مَعَهُ فِي الْمُتَطَرِّفِ»), worded as his; both narrators add the
/// rasm's faces where the hamza is written on a waw or a ya (the guide gives
/// the rasmi school to Khallad alone; the user, 2026-11-12, to Khalaf too).
int _waqfFinal(
  String id,
  Map<String, _Word> index,
  List<List> hisham,
  void Function(List v) copy,
  void Function(List row) put,
) {
  if (!_hamza.contains(id)) return 0;
  var n = 0;
  for (final v in hisham) {
    if (v.length < 9 || v[7] != 'hisham_waqf') continue;
    final word = index[_key(v[0], v[1], v[2])];
    final rasm = word != null
        ? _rasmFaces(word.t, '${v[6]}')
        : const <String>[];
    final hisWays = ((v[8] as Map)['ways'] as List).cast<String>();
    final ordered = word == null
        ? hisWays
        : _hamzaOrder(id == 'khallad', word.t, hisWays);
    final meta = Map<String, Object?>.from(v[8] as Map);
    final kind = word == null ? null : waqfHamzaKindOfFinal(word.t);
    if (kind != null) meta['kind'] = kind;
    if (rasm.isEmpty && identical(ordered, hisWays)) {
      copy([...v.take(8), meta]);
    } else {
      final ways = [...ordered, ...rasm];
      put([
        ...v.take(5),
        'u',
        'وقفًا: ${ways.join('، أو ')}',
        'hisham_waqf',
        meta
          ..['ways'] = ways
          ..['source'] = ashabSource,
      ]);
    }
    n++;
  }
  return n;
}

/// The rasm's faces of a final hamza written on a waw or a ya, which the
/// qiyasi faces ([qiyasi], Hisham's wording) do not already give.
List<String> _rasmFaces(String word, String qiyasi) {
  final t = word.replaceAll(RegExp('[ۖ-ۛ]'), '');
  final waw = RegExp(r'ؤ[ًٌٍَُِ]?(ا[ْ۟])?$').hasMatch(t);
  // ئُ، وَإِيتَآيِٕ (the hamza under the ya)، نَّبَإِيْ.
  final ya = RegExp(r'(ئ[ًٌٍَُِ]?|يٕ[ِ]?|يِٕ|إِي[ْۡ]?)$').hasMatch(t);
  if (!waw && !ya) return const [];
  final afterAlif = qiyasi.contains('إبدالها ألفًا مع القصر');
  if (waw && afterAlif) {
    // ٱلۡعُلَمَٰٓؤُاْ: the waw with the sukun or the ishmam, each with the
    // three lengths, or the rawm with the qasr.
    return const [
      'إبدالها واوًا على الرسم مع السكون والقصر',
      'إبدالها واوًا على الرسم مع السكون والتوسط',
      'إبدالها واوًا على الرسم مع السكون والمد',
      'إبدالها واوًا على الرسم مع الإشمام والقصر',
      'إبدالها واوًا على الرسم مع الإشمام والتوسط',
      'إبدالها واوًا على الرسم مع الإشمام والمد',
      'إبدالها واوًا على الرسم مع الروم والقصر',
    ];
  }
  if (ya && afterAlif) {
    // وَإِيتَآيِٕ: the ya with the sukun and the three lengths, or the rawm.
    return const [
      'إبدالها ياءً على الرسم مع السكون والقصر',
      'إبدالها ياءً على الرسم مع السكون والتوسط',
      'إبدالها ياءً على الرسم مع السكون والمد',
      'إبدالها ياءً على الرسم مع الروم والقصر',
    ];
  }
  if (waw && qiyasi.contains('إبدالها ألفًا ساكنة')) {
    // يَبۡدَؤُاْ: the waw with the sukun, the rawm or the ishmam.
    return const [
      'إبدالها واوًا على الرسم مع السكون',
      'إبدالها واوًا على الرسم مع الروم',
      'إبدالها واوًا على الرسم مع الإشمام',
    ];
  }
  if (ya && qiyasi.contains('إبدالها ألفًا ساكنة')) {
    // نَّبَإِيْ: the ya with the sukun or the rawm.
    return const [
      'إبدالها ياءً على الرسم مع السكون',
      'إبدالها ياءً على الرسم مع الروم',
    ];
  }
  if (ya && t.contains(RegExp('ئُ\$')) && qiyasi.contains('ياءً ساكنة')) {
    // يَسۡتَهۡزِئُ: the ya moved by the rasm, then quiet as the first face,
    // or with the ishmam or the rawm.
    return const [
      'إبدالها ياءً مضمومة على الرسم مع الإشمام',
      'إبدالها ياءً مضمومة على الرسم مع الروم',
    ];
  }
  return const [];
}

/// The final hamza after a waw or ya of the root, or the lin of «شيء»: the
/// naql and the merging both, the naql first for Khalaf and the merging for
/// Khallad (the guide). Hisham's rows tell «سوء» with the merging alone.
List<String> _hamzaOrder(bool khallad, String word, List<String> ways) {
  final bare = _letters(word)
      .map((x) => _isHamza(x) && x.base != 'ٱ' ? 'ء' : x.base)
      .join()
      .replaceAll(RegExp('[أإؤئآ]'), 'ء')
      .replaceAll('ـ', '');
  final shay = RegExp('شيء').hasMatch(bare);
  if (!shay && !_asliMadd(bare)) return ways;
  const merge = 'إبدالها من جنس ما قبلها وإدغامه فيه';
  final merged = [
    for (final w in ways)
      if (w.startsWith(merge) || w.startsWith('الإبدال والإدغام')) w,
  ];
  var moved = [
    for (final w in ways)
      if (w.startsWith('نقل') || w.startsWith('النقل')) w,
  ];
  if (moved.isEmpty) {
    // سُوٓءٞ: the naql with what goes with the merging.
    moved = [
      for (final w in merged)
        w
            .replaceFirst(merge, 'نقل حركتها إلى الساكن قبلها')
            .replaceFirst('الإبدال والإدغام', 'النقل'),
    ];
  }
  if (merged.isEmpty) return ways;
  String first(String w) => '$w، وهو المقدّم';
  // «شيء»: Khalaf's naql first (the guide, p3); a waw or ya of the root
  // (السوء، المسيء): the merging first for both (the user, 2026-11-12).
  return khallad || !shay
      ? [first(merged.first), ...merged.skip(1), ...moved]
      : [first(moved.first), ...moved.skip(1), ...merged];
}
