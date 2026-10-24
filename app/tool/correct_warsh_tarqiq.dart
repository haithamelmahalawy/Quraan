import 'dart:convert';
import 'dart:io';

import 'package:qiraat_mushaf/data/arabic.dart';

/// Removes automatic tarqiq annotations on kasra/kasratan ra, where there
/// is no separate fatha/damma ra. Other readings and usul remain intact.
List<Map<String, Object>> correctWarshTarqiq(
  Map quran,
  List variants, {
  Map? sourceText,
}) {
  final ayahs = {
    for (final a in quran['ayahs'] as List) '${a[0]}:${a[1]}': a as List,
  };
  final actual = <String, String>{
    if (sourceText != null)
      for (final a in sourceText['ayahs'] as List)
        for (final (w, text) in (a[2] as List).indexed)
          '${a[0]}:${a[1]}:$w': text as String,
  };
  final names = {
    for (final s in quran['surahs'] as List) s['n']: s['ar'] as String,
  };
  final removed = <Map<String, Object>>[];
  variants.removeWhere((raw) {
    final v = raw as List;
    if (v.length < 8 || v[7] != 'tarqiq') return false;
    final a = ayahs['${v[0]}:${v[1]}']!;
    final hafs = (a[4] as String).split(' ')[v[2] as int];
    final text = actual['${v[0]}:${v[1]}:${v[2]}'] ?? hafs;
    final letters = lettersOf(madinahScript(text));
    if (raLetter(letters) != null) return false;
    final ra = letters.where((l) => l.startsWith('ر')).toList();
    if (!ra.any((l) => RegExp('[ٍࣲِٖ]').hasMatch(l))) return false;
    final reason = ra.any((l) => RegExp('[ٍࣲٖ]').hasMatch(l))
        ? 'الراء منونة بالكسر؛ ترقيق مشترك مع حفص'
        : 'الراء مكسورة؛ ترقيق طبيعي في هذه القراءة';
    removed.add({
      'page': a[2] as int,
      'surah': v[0] as int,
      'surahName': names[v[0]]!,
      'ayah': v[1] as int,
      'word': (v[2] as int) + 1,
      'hafs': hafs,
      'warsh': text,
      'reason': reason,
    });
    return true;
  });
  final tagged = {
    for (final v in variants)
      if (v.length > 7 && v[7] == 'tarqiq') '${v[0]}:${v[1]}:${v[2]}',
  };
  for (final v in variants.toList()) {
    if (v[5] != 'f' || v[3] != 1 || (v[4] as String).isEmpty) continue;
    final key = '${v[0]}:${v[1]}:${v[2]}';
    if (tagged.contains(key)) continue;
    final a = ayahs['${v[0]}:${v[1]}']!;
    final hafs = (a[4] as String).split(' ')[v[2] as int];
    final word = actual[key] ?? v[4] as String;
    if (!hasWarshTarqiq(hafs) && hasWarshTarqiq(madinahScript(word))) {
      variants.add([v[0], v[1], v[2], 1, '', 'u', 'بترقيق الراء', 'tarqiq']);
      tagged.add(key);
    }
  }
  return removed;
}

void main() {
  final quran =
      jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
  final source = jsonDecode(
    File('assets/data/reading_texts/warsh.json').readAsStringSync(),
  ) as Map;
  final file = File('assets/data/qiraat/warsh.json');
  final data = jsonDecode(file.readAsStringSync()) as Map;
  final removed = correctWarshTarqiq(
    quran,
    data['variants'] as List,
    sourceText: source,
  );
  file.writeAsStringSync(jsonEncode(data));
  if (removed.isNotEmpty) {
    Directory('reports').createSync(recursive: true);
    String cell(Object value) => '"${value.toString().replaceAll('"', '""')}"';
    final csv = [
      [
        'الصفحة',
        'رقم السورة',
        'السورة',
        'الآية',
        'ترتيب الكلمة في الآية',
        'حفص',
        'ورش',
        'سبب استبعاد الترقيق',
      ],
      for (final row in removed) row.values.toList(),
    ].map((row) => row.map(cell).join(',')).join('\r\n');
    File('reports/warsh_shared_tarqiq_2026-10-24.csv')
        .writeAsStringSync('\uFEFF$csv\r\n');
  }
  final groups = <String, int>{};
  for (final row in removed) {
    groups.update(row['reason'] as String, (n) => n + 1, ifAbsent: () => 1);
  }
  stdout.writeln(
    'Removed ${removed.length} shared tarqiq annotations: $groups',
  );
}
