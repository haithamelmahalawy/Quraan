import 'dart:convert';
import 'dart:io';

import 'package:qiraat_mushaf/data/arabic.dart';

void main() {
  final source = Directory('tool/source/audio_numbering');
  dynamic read(String path) => jsonDecode(File(path).readAsStringSync());
  final boundaries = read('${source.path}/book-boundary-primitives.json');
  final systems = read('${source.path}/counting-systems.json') as Map;
  final quran = read('assets/data/quran.json');
  final wordCounts = <List<int>>[
    for (final s in quran['surahs']) List.filled(s['ayahs'] as int, 0),
  ];
  for (final a in quran['ayahs']) {
    final words = (a[4] as String).split(' ');
    wordCounts[(a[0] as int) - 1][(a[1] as int) - 1] = words.length;
    final rule = boundaries['surahs']['${a[0]}']?['${a[1]}'];
    var after = -1;
    for (final boundary in rule?['internal'] as List? ?? const []) {
      final anchor = skeleton(boundary['word'] as String);
      String plain(String s) => s
          .replaceAll(RegExp('[ٱأإآ]'), 'ا')
          .replaceAll('ى', 'ي')
          .replaceAll(RegExp('[^ء-غف-ي]'), '');
      // Prefer the actual spelling: skeleton alone conflates كثير and كثيرا.
      final exactMatches = [
        for (var w = after + 1; w < words.length - 1; w++)
          if (plain(words[w]) == plain(boundary['word'] as String)) w,
      ];
      // In 7:38 the disputed end is after عذابا ضعفا من النار, not the
      // earlier في النار. Verified against every native KFGQPC Warsh verse.
      final occurrence = a[0] == 7 && a[1] == 38 && boundary['word'] == 'النار'
          ? 2
          : 1;
      final exact = exactMatches.length >= occurrence
          ? exactMatches[occurrence - 1]
          : -1;
      final at = exact >= 0
          ? exact
          : words.indexWhere(
              (w) => skeleton(w.replaceAll(RegExp('[ۥۦ]'), '')) == anchor,
              after + 1,
            );
      if (at < 0 || at == words.length - 1) {
        throw StateError(
          'Unresolved internal boundary ${a[0]}:${a[1]}: $boundary',
        );
      }
      boundary['wordIndex'] = at;
      after = at;
    }
  }
  // Quranpedia recitation 268 (Bazzi) and the KFGQPC Bazzi print count
  // قريبا at 78:40. Recitation 269 (Qunbul) does not; keep its ordinary
  // Makkan profile separate. Verified against 078040/041/042.mp3 endpoints.
  for (final surah in (boundaries['surahs'] as Map).values) {
    for (final rule in (surah as Map).values) {
      for (final point in [
        ...rule['internal'] as List? ?? const [],
        if (rule['end'] != null) rule['end'],
      ]) {
        if ((point['counted_by'] as List).contains('makki')) {
          (point['counted_by'] as List).add('makki-6220');
        }
      }
    }
  }
  (boundaries['surahs']['78']['40']['internal'][0]['counted_by'] as List).add(
    'makki-6220',
  );
  File('assets/data/audio_numbering.json').writeAsStringSync(
    jsonEncode({
      'source': 'https://github.com/quran-ws/qiraat-ayah-map',
      'revision': 'a9b4d345f3e1d0e9282711c5e09f24119b17e4e1',
      'license': 'CC-BY-4.0; Copyright 2026 Quran.ws',
      'hafsCounts': [for (final s in quran['surahs']) s['ayahs']],
      'wordCounts': wordCounts,
      'totals': {
        for (final s in systems.entries) s.key: s.value['total_ayahs'],
        'makki-6220': 6220,
      },
      'boundaries': boundaries['surahs'],
    }),
  );
}
