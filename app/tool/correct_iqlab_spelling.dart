import 'build_data.dart' show classify;

/// Old comparisons mistook iqlab tanween written on the final alif for a
/// changed vowel. Drop only single-word lexical rows that now compare as
/// identical; independent usul and actual lexical differences survive.
int correctIqlabSpelling(Map quran, List variants) {
  final words = <String, List<String>>{
    for (final a in quran['ayahs'] as List)
      '${a[0]}:${a[1]}': (a[4] as String).split(' '),
  };
  final before = variants.length;
  variants.removeWhere((raw) {
    final v = raw as List;
    if (v[3] != 1 || v[5] != 'f' || v.length > 7 && v[7] != '') {
      return false;
    }
    final text = v[4] as String;
    if (!RegExp(r'اَۢ[ۖ-ۭ]*$').hasMatch(text)) return false;
    final hafs = words['${v[0]}:${v[1]}']![v[2] as int];
    return classify(hafs, text) == null;
  });
  return before - variants.length;
}
