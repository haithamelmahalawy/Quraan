import 'dart:convert';
import 'dart:io';

/// Snapshot of the stopping-only Warsh annotations actually used by the app.
/// Pages come from printed word locations, including split ayahs.
void main() {
  Map read(String file) =>
      jsonDecode(File('assets/data/$file.json').readAsStringSync()) as Map;
  final quran = read('quran');
  final words = <({String key, int surah, int ayah, int word, String text})>[
    for (final a in quran['ayahs'] as List)
      for (final (w, text) in (a[4] as String).split(' ').indexed)
        (
          key: '${a[0]}:${a[1]}:$w',
          surah: a[0] as int,
          ayah: a[1] as int,
          word: w,
          text: text,
        ),
  ];
  final index = {for (final (i, w) in words.indexed) w.key: i};
  final pages = <String, int>{};
  for (final (p, lines) in (read('layout')['pages'] as List).indexed) {
    for (final l in lines as List) {
      if (l is! List || l[0] != 'a') continue;
      final from = index['${l[1]}:${l[2]}:${l[3]}']!;
      final to = index['${l[4]}:${l[5]}:${l[6]}']!;
      for (var i = from; i <= to; i++) {
        pages[words[i].key] = p + 1;
      }
    }
  }
  final names = {for (final s in quran['surahs'] as List) s['n']: s['ar']};
  final keys = <String>{
    for (final v in read('qiraat/warsh')['variants'] as List)
      if (v.length > 8 && v[7] == 'taqlil_stop' && v[8]['stopOnly'] == true)
        '${v[0]}:${v[1]}:${v[2]}',
  };
  final rows = [
    for (final w in words)
      if (keys.contains(w.key)) w,
  ];
  final csv =
      [
            [
              'الصفحة',
              'السورة',
              'رقم السورة',
              'الآية',
              'ترتيب الكلمة',
              'الكلمة',
              'الحكم',
            ],
            for (final w in rows)
              [
                pages[w.key]!,
                names[w.surah]!,
                w.surah,
                w.ayah,
                w.word + 1,
                w.text,
                'تقليل وقفًا فقط؛ نقطة داخل دائرة صغيرة',
              ],
          ]
          .map(
            (row) => row
                .map((v) => '"${v.toString().replaceAll('"', '""')}"')
                .join(','),
          )
          .join('\r\n');
  Directory('reports').createSync(recursive: true);
  File('reports/warsh_stopping_taqlil_2026-10-24.csv')
      .writeAsStringSync('\uFEFF$csv\r\n');
  stdout.writeln(
    '${rows.length} unique stopping taqlil positions on ${rows.map((w) => pages[w.key]).toSet().length} pages.',
  );
  for (final w in rows) {
    stdout.writeln('${pages[w.key]} | ${names[w.surah]} ${w.ayah} | ${w.text}');
  }
}
