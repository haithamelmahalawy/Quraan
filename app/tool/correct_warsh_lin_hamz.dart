import 'package:qiraat_mushaf/data/lin_hamz.dart';

/// Annotation-only rules: never rewrite the Quran word or replace another
/// independent reading at the same location. Called by build_warsh_usul.
Map<String, int> correctWarshLinHamz(Map quran, List variants) {
  final rules = {for (final kind in LinHamz.values) kind.rule};
  variants.removeWhere((v) => v.length > 7 && rules.contains(v[7]));
  final counts = <String, int>{};
  for (final a in quran['ayahs'] as List) {
    for (final (w, text) in (a[4] as String).split(' ').indexed) {
      final kind = LinHamz.of(text);
      if (kind == null) continue;
      variants.add([
        a[0],
        a[1],
        w,
        1,
        '',
        'u',
        kind.description,
        kind.rule,
        {'ways': kind.ways},
      ]);
      counts[kind.rule] = (counts[kind.rule] ?? 0) + 1;
    }
  }
  return counts;
}
