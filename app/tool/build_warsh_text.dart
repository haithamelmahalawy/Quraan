// Complete Warsh text, aligned onto the existing Hafs pages and word anchors.
// It is deliberately independent of the book's margin/annotation data.
import 'dart:convert';
import 'dart:io';

import 'build_data.dart' show HafsWord, sourceWords, alignSourceWords;

Map<String, Object> buildWarshText(Map base, List<Map> source) {
  final ayahs = base['ayahs'] as List;
  final out = <List<Object>>[];
  for (var s = 1; s <= 114; s++) {
    final sourceText = source
        .where((a) => a['sura_no'] == s)
        // The source export joins نأى and بجانبه at Fussilat 41:51.
        // Restore that word boundary without changing a letter or vowel.
        .expand(
          (a) => sourceWords(
            (a['aya_text'] as String).replaceAll(
              'ابِجَانِبِهِ',
              'ا بِجَانِبِهِ',
            ),
          ),
        )
        .toList();
    final anchors = <HafsWord>[
      for (final a in ayahs.where((a) => a[0] == s))
        for (final (w, text) in (a[4] as String).split(' ').indexed)
          HafsWord(s, a[1] as int, w, text),
    ];
    // Warsh's Madani verse numbering does not count the Fatiha basmala.
    if (s == 1) {
      sourceText.insertAll(
        0,
        anchors.takeWhile((w) => w.ayah == 1).map((w) => w.text),
      );
    }
    final slots = alignSourceWords(anchors, sourceText);
    if (slots.where((w) => w.isNotEmpty).join(' ') != sourceText.join(' ')) {
      throw StateError('Source text changed while aligning surah $s');
    }
    var start = 0;
    while (start < anchors.length) {
      var end = start + 1;
      while (end < anchors.length && anchors[end].ayah == anchors[start].ayah) {
        end++;
      }
      out.add([s, anchors[start].ayah, slots.sublist(start, end)]);
      start = end;
    }
  }
  return {
    'riwaya': 'warsh',
    'source': 'KFGQPC warshData_v10.json; complete source text aligned to Hafs anchors',
    'ayahs': out,
  };
}

void main() {
  final base =
      jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
  final source = (jsonDecode(
    File('../tools/source/warshData_v10.json')
        .readAsStringSync()
        .replaceFirst('\uFEFF', ''),
  ) as List).cast<Map>();
  final data = buildWarshText(base, source);
  File('assets/data/reading_texts/warsh.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(jsonEncode(data));
  stdout.writeln(
    'Complete Warsh text: ${(data['ayahs'] as List).length} Hafs-anchored ayahs; all 114 surahs round-trip exactly.',
  );
}
