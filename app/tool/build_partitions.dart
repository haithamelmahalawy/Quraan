import 'dart:convert';
import 'dart:io';

/// Uses the Quran.com verse metadata already downloaded for the layout.
void main() {
  final metadata = <String, Map>{};
  for (var s = 1; s <= 114; s++) {
    final data = jsonDecode(
      File('../tools/source/layout/s$s.json').readAsStringSync(),
    ) as Map;
    for (final v in data['verses'] as List) {
      metadata[v['verse_key'] as String] = v as Map;
    }
  }
  final quran =
      jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
  final starts = <List<int>>[];
  var previous = 0;
  for (final a in quran['ayahs'] as List) {
    final v = metadata['${a[0]}:${a[1]}'];
    if (v == null) {
      throw StateError('Missing partition metadata: ${a[0]}:${a[1]}');
    }
    final rub = v['rub_el_hizb_number'] as int;
    if (rub != previous) {
      if (rub != previous + 1) throw StateError('Non-consecutive quarter $rub');
      starts.add([a[0] as int, a[1] as int]);
      previous = rub;
    }
  }
  if (starts.length != 240) throw StateError('Expected 240 quarters');
  File('assets/data/partitions.json').writeAsStringSync(
    jsonEncode({
      'source': 'Quran.com verse metadata (tools/source/layout/s1.json ... s114.json)',
      'rub': starts,
    }),
  );
  stdout.writeln('Wrote ${starts.length} quarter starts for all readings.');
}
