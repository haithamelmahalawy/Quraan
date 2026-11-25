// Apply the reviewed readings while preserving unrelated riwaya/rule rows.
// Source: al-Tasheel, reviewed notes on mushaf pages 413–601.
// Run from app/: dart run tool/correct_reviewed_farsh.dart
import 'dart:convert';
import 'dart:io';

/// «وَكِتَٰبِهِۦ» read in the singular, by every reader who reads it so.
const kitabihiDescription = 'بكسر الكاف وفتح التاء وإثبات الألف (على الإفراد)';

/// «لِيَسُوٓأَ» (الإسراء ٧) of Ibn 'Amir, Shu'ba, Hamza and Khalaf al-'Ashir: its
/// hamza over an alif, after the madd (the user, 2026-11-24).
const liyasuaText = 'لِيَسُوٓأَ';
const liyasuaDescription = 'بهمز مفتوح في نهاية الكلمة وحذف الواو الأخيرة';

/// «ٱئۡتُونِيٓ» (الكهف ٩٦) of Shu'ba and Hamza: the alif of joining, then the
/// quiet hamza on its nabra (the user, 2026-11-24).
const ituniText = 'ٱئۡتُونِيٓ';
const ituniDescription = 'بإسكان الهمزة وحذف الألف';

/// «ٱلظُّنُونَاْ، ٱلرَّسُولَاْ، ٱلسَّبِيلَاْ» (الأحزاب ١٠، ٦٦، ٦٧).
const alifDropped = [(10, 15), (66, 10), (67, 7)];

/// A row dropping the alif of [alifDropped] joined and stopped.
bool dropsAlif(List row) =>
    row[0] == 33 &&
    alifDropped.contains((row[1], row[2])) &&
    '${row[6]}'.startsWith('بحذف الألف وصلاً ووقف');

/// Hafs's word, the round sukun (ْ) over the alif in place of his oval one.
String roundSukun(String hafs) => hafs.replaceAll('۠', 'ْ');

/// «ٱلتَّنَآؤُشُ» (سبأ ٥٢), its hamza after the alif.
const tanawushDescription = 'بالهمز مع المد المتصل';

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
  // «فَـَٔاذِنُواْ» (البقرة ٢٧٩) of Shu'ba and Hamza: the fa kept, not dropped
  // (the user, 2026-11-18).
  for (final row in rows) {
    if (row[0] == 2 &&
        row[1] == 279 &&
        row[2] == 3 &&
        (row[4] as String).contains('اذِنُواْ')) {
      row[6] = 'بفتح الهمزة وإثبات الألف وكسر الذال';
    }
  }
  // «وَكِتَٰبِهِۦ» (البقرة ٢٨٥، التحريم ١٢): one description for every reader
  // who reads it so (the user, 2026-11-18).
  for (final row in rows) {
    if (row.length > 6 && row[5] == 'f' && row[4] == 'وَكِتَٰبِهِۦ') {
      row[6] = kitabihiDescription;
    }
  }
  // «فَنَعِمَّا، نَعِمَّا» (البقرة ٢٧١، النساء ٥٨): the nun's fatha alone, the
  // ain's kasra Hafs's too (the user, 2026-11-18).
  for (final row in rows) {
    if (row.length > 6 &&
        row[5] == 'f' &&
        RegExp(r'^ف?نعما$')
            .hasMatch((row[4] as String).replaceAll(RegExp('[ً-ٰ]'), ''))) {
      row[6] = 'بفتح النون';
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
  // «لِيَسُوٓأَ» (الإسراء ٧) of Ibn 'Amir and Shu'ba, as of Hamza and Khalaf
  // al-'Ashir (the user, 2026-11-24).
  if (const {'hisham', 'ibn_dhakwan', 'shubah'}.contains(id)) {
    rows.removeWhere(
      // And the old «لِيَسُوٓءَ» of the hamesh, without a description.
      (r) =>
          r[0] == 17 &&
          r[1] == 7 &&
          r[2] == 11 &&
          (r[5] == 'f' || r[5] == 'h' && '${r.length > 6 ? r[6] : ''}'.isEmpty),
    );
    final next = rows.indexWhere(
      (r) => r[0] > 17 || r[0] == 17 && (r[1] > 7 || r[1] == 7 && r[2] > 11),
    );
    rows.insert(next < 0 ? rows.length : next, <Object>[
      17,
      7,
      11,
      1,
      liyasuaText,
      'f',
      liyasuaDescription,
    ]);
  }
  // «ٱلظُّنُونَاْ، ٱلرَّسُولَاْ، ٱلسَّبِيلَاْ» (الأحزاب ١٠، ٦٦، ٦٧) of those who drop
  // the alif joined and stopped: drawn with it, the round sukun over it; Abu
  // 'Amr reads them so too, with the same note (the user, 2026-11-25).
  if (id == 'duri_abuamr' || id == 'susi') {
    for (final (ayah, word) in alifDropped) {
      if (rows.any((r) => r[0] == 33 && r[1] == ayah && r[2] == word)) {
        continue;
      }
      final key = 33000000 + ayah * 1000 + word;
      final next = rows.indexWhere(
        (r) =>
            (r[0] as int) * 1000000 + (r[1] as int) * 1000 + (r[2] as int) >
            key,
      );
      rows.insert(next < 0 ? rows.length : next, [
        33,
        ayah,
        word,
        1,
        '',
        'f',
        'بحذف الألف وصلاً ووقفًا',
      ]);
    }
  }
  for (final row in rows) {
    if (!dropsAlif(row)) continue;
    final a = (quran['ayahs'] as List).firstWhere(
      (a) => a[0] == 33 && a[1] == row[1],
    );
    row[4] = roundSukun((a[4] as String).split(' ')[row[2] as int]);
  }
  // «ٱلتَّنَآؤُشُ» (سبأ ٥٢): one note for Abu 'Amr, Shu'ba, Hamza, al-Kisa'i and
  // Khalaf al-'Ashir (the user, 2026-11-25).
  for (final row in rows) {
    if (row[0] == 34 && row[1] == 52 && row[2] == 5 && row[5] == 'h') {
      row[6] = tanawushDescription;
    }
  }
  if (id != 'shubah') return;

  // «ٱئۡتُونِي زُبَرَ»، «قَالَ ٱئۡتُونِيٓ» (الكهف ٩٦): on its nabra and told as
  // Hamza's (the user, 2026-11-24).
  for (final row in rows) {
    if (row[0] == 18 && row[1] == 96 && (row[2] == 0 || row[2] == 15)) {
      if ('${row[4]}'.contains('تُونِي') && '${row[4]}'.startsWith('ٱ')) {
        row[4] = row[2] == 0 ? 'ٱئۡتُونِي' : ituniText;
        row[6] = ituniDescription;
      }
    }
  }

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
  // Hafs's sakt left, as Warsh: in the usul «ترك السكت», the two words shaded
  // together (the user, 2026-11-16).
  put([
    36,
    52,
    5,
    2,
    'مَّرۡقَدِنَاۗ هَٰذَا',
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
  put([
    56,
    66,
    0,
    1,
    // On its nabra, as «أَئِنَّكُمۡ» (the user, 2026-11-20).
    'أَئِنَّا',
    'f',
    'بزيادة همزة استفهام',
  ]);
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
  // Both words joined, the lam bare and the ra doubled (the user, 2026-11-17).
  put([
    83,
    14,
    1,
    2,
    'بَل رَّانَ',
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
