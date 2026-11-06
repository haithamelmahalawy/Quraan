// Apply the reviewed readings while preserving unrelated riwaya/rule rows.
// Source: al-Tasheel, reviewed notes on mushaf pages 413–601.
// Run from app/: dart run tool/correct_reviewed_farsh.dart
import 'dart:convert';
import 'dart:io';

void correctReviewedFarsh(String id, Map quran, List rows) {
  // This spelling is shared by everyone who reads نِعْمَةً at 31:20.
  for (final row in rows) {
    if (row[0] == 31 &&
        row[1] == 20 &&
        row[2] == 14 &&
        (row[4] as String).contains('ة')) {
      row[5] = 'f';
      row[6] = 'بإسكان العين وإبدال الهاء تاء مربوطة منونة بالفتح';
    }
  }
  // «ٱسۡتُحِقَّ» (المائدة ١٠٧): «وَضَمَّ اسْتُحِقَّ افْتَحْ لَحِفْصٍ وَكَسْرَهُ».
  if (!rows.any(
    (r) => r[0] == 5 && r[1] == 107 && r[2] <= 11 && r[2] + r[3] > 11,
  )) {
    final next = rows.indexWhere(
      (r) => r[0] > 5 || r[0] == 5 && (r[1] > 107 || r[1] == 107 && r[2] > 11),
    );
    rows.insert(next < 0 ? rows.length : next, <Object>[
      5,
      107,
      11,
      1,
      'ٱسۡتُحِقَّ',
      'f',
      'بضم التاء وكسر الحاء',
    ]);
  }
  if (id != 'shubah') return;

  void put(List<Object> row) {
    final i = rows.indexWhere(
      (r) => r[0] == row[0] && r[1] == row[1] && r[2] == row[2],
    );
    if (i >= 0) {
      rows[i] = row;
    } else {
      final key =
          (row[0] as int) * 1000000 + (row[1] as int) * 1000 + (row[2] as int);
      final next = rows.indexWhere(
        (r) =>
            (r[0] as int) * 1000000 + (r[1] as int) * 1000 + (r[2] as int) >
            key,
      );
      rows.insert(next < 0 ? rows.length : next, row);
    }
  }

  put([33, 51, 0, 1, 'تُرۡجِئُ', 'f', 'بإبدال الياء همزة مضمومة']);
  for (final (ayah, word) in [(10, 15), (66, 10), (67, 7)]) {
    final a = (quran['ayahs'] as List).firstWhere(
      (a) => a[0] == 33 && a[1] == ayah,
    );
    final text = (a[4] as String)
        .split(' ')[word]
        .replaceAll(RegExp('[۠۟]'), '');
    put([33, ayah, word, 1, text, 'f', 'بإثبات الألف وصلاً ووقفاً']);
  }
  put([
    35,
    33,
    9,
    1,
    'وَلُولُؤٗاۖ',
    'f',
    'بإبدال الهمزة الأولى واوًا ساكنة مدية',
  ]);
  // Hafs's sakt left, as Warsh: in the usul «ترك السكت».
  put([
    36,
    52,
    5,
    1,
    '',
    'u',
    'بالوصل دون سكت',
    'no_sakt',
    {'context': 'مَّرۡقَدِنَاۜۗ هَٰذَا'},
  ]);
  put([
    40,
    46,
    8,
    1,
    'ٱدۡخُلُوٓاْ',
    'f',
    'فعل أمر بهمزة وصل وضم الخاء، ويُبدأ بها بهمزة مضمومة',
  ]);
  put([
    55,
    24,
    2,
    1,
    'ٱلۡمُنشِـَٔاتُ',
    'f',
    '',
    '',
    {'wujuh': 'بوجهين: الأول بكسر الشين وهو المقدم، والثاني بفتح الشين'},
  ]);
  put([56, 66, 0, 1, 'أَءِنَّا', 'f', 'بزيادة همزة استفهام']);
  for (final (word, text) in [(15, 'ٱنشِزُواْ'), (16, 'فَٱنشِزُواْ')]) {
    put([
      58,
      11,
      word,
      1,
      text,
      'f',
      '',
      '',
      {'wujuh': 'بوجهين: الأول بكسر الشين وهو المقدم، والثاني بضم الشين'},
    ]);
  }
  put([61, 8, 7, 1, 'نُّورَهُۥ', 'f', 'بالإدغام وفتح الراء وضم الهاء']);
  put([65, 3, 14, 1, 'أَمۡرَهُۥۚ', 'f', 'بفتح الراء وضم الهاء']);
  put([
    66,
    4,
    14,
    1,
    'وَجَبۡرَئِلُ',
    'f',
    'بفتح الجيم والراء وهمزة مكسورة بدل الياء',
  ]);
  rows.removeWhere((r) => r[0] == 69 && r[1] == 41 && r[2] == 6);
  put([
    75,
    27,
    1,
    1,
    '',
    'u',
    'بالإدغام دون سكت',
    'no_sakt',
    {'context': 'مَنۡۜ رَاقٖ'},
  ]);
  put([
    75,
    36,
    4,
    1,
    'سُدَ۪ى',
    'u',
    'بإمالة الألف وقفًا',
    '',
    {'stopOnly': true},
  ]);
  for (final (ayah, word) in [(15, 7), (16, 0)]) {
    put([
      76,
      ayah,
      word,
      1,
      'قَوَارِيرٗا',
      'f',
      'بتنوين الراء بالفتح وصلًا، وإبدال التنوين ألفًا وقفًا',
    ]);
  }
  put([
    83,
    14,
    1,
    1,
    '',
    'u',
    'بالإدغام دون سكت',
    'no_sakt',
    {'context': 'بَلۡۜ رَانَ'},
  ]);
  put([83, 14, 2, 1, 'رّٜانَ', 'u', 'بالإمالة']);
  put([104, 8, 2, 1, 'مُّوصَدَةٞ', 'f', 'بإبدال الهمزة واوًا مدية']);
}

void main() {
  final quran =
      jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
  for (final file in Directory(
    'assets/data/qiraat',
  ).listSync().whereType<File>()) {
    if (!file.path.endsWith('.json')) continue;
    final data = jsonDecode(file.readAsStringSync()) as Map;
    final before = jsonEncode(data);
    correctReviewedFarsh(
      data['riwaya'] as String,
      quran,
      data['variants'] as List,
    );
    if (jsonEncode(data) != before) {
      file.writeAsStringSync(jsonEncode(data));
      stdout.writeln('Corrected ${data['riwaya']}');
    }
  }
}
