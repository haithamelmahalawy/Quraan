// «التقاء الساكنين»: the first of two quiescents, before a hamza of wasl
// whose third letter has a lasting damma, moved with a damma by those who
// follow it («وضمك أولى الساكنين لثالث، يضم لزوما كسره في ند حلا»); Asim,
// Ya'qub and Hamza read it with a kasra, as Hafs: nothing to tell for them.
// Run from app/: dart run tool/apply_first_sakin.dart
import 'dart:convert';
import 'dart:io';

const firstSakinSource = 'first_sakin';

/// Those who read it with a damma. Ibn Dhakwan in the letters only, his
/// tanween with a kasra, as Hafs, but for its two faces in برحمة and خبيثة.
const firstSakinDamm = {
  'warsh',
  'qalun',
  'bazzi',
  'qunbul',
  'hisham',
  'ibn_dhakwan',
  'ibn_wardan',
  'ibn_jammaz',
};

/// The words of Hafs's text where the two quiescents meet: (surah, ayah,
/// word, whether it is a tanween).
List<(int, int, int, bool)> firstSakinSites(Map quran) {
  final words = <(int, int, int, String)>[
    for (final x in quran['ayahs'] as List)
      for (final (i, w) in (x[4] as String).split(' ').indexed)
        (x[0] as int, x[1] as int, i, w),
  ];
  final letter = RegExp('[نلتدو]ِ[ۖ-ۜ]*\$');
  final tanween = RegExp('[ًٌٍٖٗٞ][اى]?[ۖ-ۜ]*\$');
  // A hamza of wasl, its second letter quiescent (not the article's lam),
  // its third with a damma.
  final wasl = RegExp('^ٱ(?!ل)[^ًٌٍَُِّْۡ]ۡ?[^ًٌٍَُِّْۡ]ّ?ُ');
  // Their damma passing (ٱمۡشُواْ، ٱمۡرُؤٌاْ), or of a word read otherwise.
  const passing = [
    'ٱمۡشُواْ',
    'ٱقۡضُوٓاْ',
    'ٱبۡنُواْ',
    'ٱئۡتُ',
    'ٱمۡرُؤٌ',
    'ٱسۡمُهُ',
    'ٱبۡنُ',
  ];
  // «لِلۡإِنسَٰنِ ٱكۡفُرۡ»: the nun's kasra is its case, not to part the two.
  const not = {'59:16:4'};
  return [
    for (var n = 0; n + 1 < words.length; n++)
      if (words[n + 1].$1 == words[n].$1 &&
          wasl.hasMatch(words[n + 1].$4) &&
          !passing.any(words[n + 1].$4.startsWith) &&
          !not.contains('${words[n].$1}:${words[n].$2}:${words[n].$3}') &&
          (letter.hasMatch(words[n].$4) || tanween.hasMatch(words[n].$4)))
        (words[n].$1, words[n].$2, words[n].$3, !letter.hasMatch(words[n].$4)),
  ];
}

const _letterNames = {
  'ن': 'النون',
  'ل': 'اللام',
  'ت': 'التاء',
  'د': 'الدال',
  'و': 'الواو',
};

/// Tells it in [rows] of [id] as one rule, in place of the farsh the sources
/// gave: one row a word, in the usul.
void applyFirstSakin(String id, Map quran, List rows) {
  if (!firstSakinDamm.contains(id)) return;
  rows.removeWhere(
    (v) => v.length > 8 && v[8] is Map && v[8]['source'] == firstSakinSource,
  );
  final hafs = <String, String>{
    for (final x in quran['ayahs'] as List)
      for (final (i, w) in (x[4] as String).split(' ').indexed)
        '${x[0]}:${x[1]}:$i': w,
  };
  final sites = {
    for (final (s, a, w, t) in firstSakinSites(quran)) '$s:$a:$w': t,
  };
  final damm = RegExp(
    r'(^|و)ب?(ضم (النون|اللام|الدال|التاء|الواو)|ضم نون التنوين[^،؛]*|'
    r'الضم في الوصل|بوجهين: بضم نون التنوين.*)',
  );
  bool tells(List v) =>
      v.length > 6 &&
      (v.length > 7 && v[7] == 'first_sakin' ||
          damm.hasMatch('${v[6]}'.trim()));
  final added = <List>[];
  // A row told of a span that holds the place («عليهِمُ أنُ»), or told on
  // the word after a tanween at an ayah's end: told again on its word.
  for (final v in [...rows]) {
    if (!tells(v)) continue;
    final s = v[0] as int, a = v[1] as int, w = v[2] as int;
    final n = (v[3] as num).toInt();
    final here = sites.containsKey('$s:$a:$w');
    final spans = [
      for (var d = 1; d < n; d++)
        if (sites.containsKey('$s:$a:${w + d}')) w + d,
    ];
    final rule = v.length > 7 && v[7] == 'first_sakin';
    if (here ||
        !rule &&
            !RegExp('لالتقاء الساكنين|الضم في الوصل').hasMatch('${v[6]}')) {
      continue;
    }
    if (spans.isNotEmpty || '${v[6]}'.contains('التنوين')) {
      rows.remove(v);
    } else if (rule) {
      // A farsh of the word told here by mistake (يَبْطُشُ، زُلُفاً).
      v[5] = 'f';
      v[7] = '';
    }
  }
  for (final MapEntry(key: key, value: isTanween) in sites.entries) {
    final [s, a, w] = key.split(':').map(int.parse).toList();
    final at = <List>[
      for (final v in rows.cast<List>())
        if (v[0] == s && v[1] == a && v[2] == w) v,
    ];
    for (final v in at.where(tells)) {
      final how = '${v[6]}'.trim();
      final m = damm.firstMatch(how)!;
      final text = '${v[4]}'.split(' ');
      // What else it tells, of the word after (اضطِر): its own farsh there.
      final rest = (how.substring(0, m.start) + how.substring(m.end))
          .replaceAll('لالتقاء الساكنين', '')
          .replaceFirst(RegExp(r'^\s*و'), '')
          .trim();
      rows.remove(v);
      if (rest.isNotEmpty && (v[3] as num) > 1) {
        added.add([
          s,
          a,
          w + 1,
          1,
          text.length > 1 ? text[1] : '',
          'f',
          rest.startsWith('ب') ? rest : 'ب$rest',
          '',
        ]);
      }
    }
    // Ibn Dhakwan's tanween: as Hafs, but for his two faces in برحمة, خبيثة.
    final twoFaces =
        id == 'ibn_dhakwan' && const {'7:49:6', '14:26:4'}.contains(key);
    if (isTanween && id == 'ibn_dhakwan' && !twoFaces) continue;
    final word = hafs[key]!;
    final written = at.any((v) => !tells(v) && '${v[4]}'.isNotEmpty);
    final text = isTanween || written
        ? ''
        : word.replaceFirstMapped(RegExp('ِ([ۖ-ۜ]*)\$'), (m) => 'ُ${m[1]}');
    final bare = word.replaceAll(RegExp('[ًٌٍَُِّْٰۖ-ۭ]'), '');
    final letter = _letterNames[bare[bare.length - 1]];
    final how = twoFaces
        ? 'بوجهين: ضم نون التنوين وصلاً لالتقاء الساكنين، وهو المقدّم؛ أو كسرها كحفص'
        : isTanween
        ? 'بضم نون التنوين وصلاً لالتقاء الساكنين'
        : 'بضم $letter لالتقاء الساكنين';
    added.add([
      s,
      a,
      w,
      1,
      text,
      'u',
      how,
      'first_sakin',
      {
        'source': firstSakinSource,
        if (twoFaces)
          'ways': ['ضم نون التنوين وصلاً، وهو المقدّم', 'كسرها كحفص'],
      },
    ]);
  }
  // In the order of the words, after the rows already there.
  int order(List v) =>
      (v[0] as int) * 1000000 + (v[1] as int) * 1000 + (v[2] as int);
  for (final v in added) {
    final next = rows.indexWhere((o) => order(o) > order(v));
    rows.insert(next < 0 ? rows.length : next, v);
  }
}

void main() {
  final quran =
      jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
  for (final id in firstSakinDamm) {
    final file = File('assets/data/qiraat/$id.json');
    final data = jsonDecode(file.readAsStringSync()) as Map;
    final before = jsonEncode(data);
    applyFirstSakin(id, quran, data['variants'] as List);
    if (jsonEncode(data) != before) {
      file.writeAsStringSync(jsonEncode(data));
      stdout.writeln('Applied $id');
    }
  }
}
