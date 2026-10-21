// Re-describes, in place, the readings of the KFGQPC riwayat that the
// description generator of build_data.dart used to word wrongly: tanween
// (مُوهِنٌ was «بإسكان النون», مُسَخَّرَٰتٍۭ «بكسر التاء والتقليل») and a ha
// read with sukun (يُؤَدِّهۡ was «بترك صلة الهاء», now «بإسكان الهاء»).
// Other readings, and the rules tool/build_usul.dart added, are kept.
//
//   dart run tool/redescribe.dart
import 'dart:convert';
import 'dart:io';

import 'build_data.dart' as data show describe, currentRiwaya;

const kfgqpc = ['qalun', 'warsh', 'bazzi', 'qunbul', 'duri_abuamr', 'susi', 'shubah'];

void main() {
  final quran = jsonDecode(File('assets/data/quran.json').readAsStringSync())
      as Map<String, dynamic>;
  final words = <String, List<String>>{
    for (final a in quran['ayahs'] as List)
      '${a[0]}:${a[1]}': (a[4] as String).split(' '),
  };
  for (final id in kfgqpc) {
    final file = File('assets/data/qiraat/$id.json');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    data.currentRiwaya = id;
    var changed = 0;
    for (final v in json['variants'] as List) {
      if (v.length > 7 || v[3] != 1 || (v[4] as String).isEmpty) continue;
      final hafs = words['${v[0]}:${v[1]}']![v[2] as int];
      final old = v.length > 6 ? v[6] as String : '';
      final now = data.describe(hafs, v[4] as String);
      if (now.isEmpty || now == old || old.contains('سكت')) continue;
      final tanween = now.contains('تنوين') || old.contains('تنوين');
      final haSukun = now.contains('إسكان الهاء') && old.contains('ترك صلة الهاء');
      if (!tanween && !haSukun) continue;
      v.length > 6 ? v[6] = now : v.add(now);
      // A vowel or a sukun of the farsh, not a silah (usul).
      if (haSukun) v[5] = 'f';
      changed++;
      if (changed <= 4) stdout.writeln('$id ${v[0]}:${v[1]} $hafs → ${v[4]}: $old → $now');
    }
    if (changed > 0) {
      file.writeAsStringSync(jsonEncode(json));
      stdout.writeln('$id: $changed');
    }
  }
}
