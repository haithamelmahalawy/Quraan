import 'dart:convert';
import 'dart:io';

import 'package:qiraat_mushaf/data/arabic.dart';

int correctYaZawaid(Map quran, List variants, String riwaya, [Map? book]) {
  final ayahs = <String, List<String>>{
    for (final a in quran['ayahs'] as List)
      '${a[0]}:${a[1]}': (a[4] as String).split(' '),
  };
  var corrected = 0;
  for (final v in variants.cast<List>()) {
    if (v[3] != 1 || (v[4] as String).isEmpty) continue;
    final hafs = ayahs['${v[0]}:${v[1]}']![v[2] as int];
    final last = lettersOf(hafs).last;
    if (!last.contains('ِ') ||
        'هيى'.contains(last[0]) ||
        skeleton(madinahScript(v[4] as String)) != '${skeleton(hafs)}ي') {
      continue;
    }
    var waslOnly = riwaya == 'warsh';
    var both = false;
    if (book != null) {
      for (final e in book['entries'] as List) {
        if (e[0] != v[0] ||
            e[1] != v[1] ||
            v[2] < e[2] ||
            v[2] >= e[2] + e[3]) {
          continue;
        }
        for (final g in e[5] as List) {
          if (!(g[1] as List).contains(riwaya) &&
              !(g[2] as List).contains(riwaya)) {
            continue;
          }
          final how = (g[3] as String).replaceAll(RegExp('[ً-ٰٟ]'), '');
          both |= how.contains('الحالين');
          waslOnly |= how.contains('وصلا') && !how.contains('وقفا');
        }
      }
    }
    final how = both
        ? 'بإثبات الياء الزائدة وصلاً ووقفًا'
        : waslOnly
        ? 'بإثبات الياء الزائدة وصلاً وحذفها وقفًا'
        : 'بإثبات الياء الزائدة';
    final ways = both
        ? ['إثبات الياء وصلاً ووقفًا']
        : waslOnly
        ? ['إثبات الياء وصلاً', 'حذف الياء وقفًا']
        : <String>[];
    while (v.length < 9) {
      v.add(null);
    }
    v[5] = 'u';
    v[6] = how;
    v[7] = 'ya_zaida';
    v[8] = {'ways': ways};
    corrected++;
  }
  return corrected;
}

void main() {
  final quran =
      jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
  final book =
      jsonDecode(File('assets/data/kharouf.json').readAsStringSync()) as Map;
  for (final f in Directory(
    'assets/data/qiraat',
  ).listSync().whereType<File>()) {
    if (!f.path.endsWith('.json')) continue;
    final data = jsonDecode(f.readAsStringSync()) as Map;
    final before = jsonEncode(data);
    final n = correctYaZawaid(
      quran,
      data['variants'] as List,
      data['riwaya'] as String,
      book,
    );
    if (jsonEncode(data) != before) f.writeAsStringSync(jsonEncode(data));
    if (n > 0) stdout.writeln('${data['riwaya']}: $n extra-ya readings');
  }
}
