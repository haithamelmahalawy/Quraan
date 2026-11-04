// Nafi''s added hamza of «ٱلنَّبِيٓءُ» and its bab (ٱلنَّبِيٓـِٕۧنَ، أَنۢبِئَآءَ،
// ٱلنُّبُوٓءَةَ): one usul, «الهمز المفرد (زيادة الهمزة)», for Qalun and Warsh,
// never in the farsh; worded without «والمد», Warsh's «مع ثلاثة البدل» where
// his badal is read. Its small ya stands after the hamza, apart from it.
// Run from app/: dart run tool/apply_hamza_zaida.dart
import 'dart:convert';
import 'dart:io';

const hamzaZaidaReaders = {'qalun', 'warsh'};

String _bare(String t) => t.replaceAll(RegExp('[ً-ٰٟۖ-ۭـ]'), '');

/// Hafs's word of the bab: نبي، نبيين، أنبياء، النبوة.
bool _ofBab(String hafs) => RegExp('نبي|نبو').hasMatch(_bare(hafs));

final _told = RegExp(
  r'زيادة الهمزة|^بالهمز|^بصلة ميم الجمع والهمز|إبدال الياء همزة',
);

/// Nafi''s and Abu Ja'far's «وَٱلصَّٰبِـِٔينَ، وَٱلصَّٰبِـُٔونَ» without the hamza:
/// «الهمز المفرد (حذف الهمزة)», not the farsh; written as Hafs, its alif the
/// dagger one, all vowelled.
const _sabiin = {
  '2:62:6': ('وَالصَّٰبِينَ', 'بحذف الهمزة'),
  '5:69:5': ('وَالصَّٰبُونَ', 'بضم الباء وحذف الهمزة'),
  '22:17:5': ('وَالصَّٰبِينَ', 'بحذف الهمزة'),
};

void applyHamzaHadhf(String id, List rows) {
  if (!const {'qalun', 'warsh', 'ibn_wardan', 'ibn_jammaz'}.contains(id)) {
    return;
  }
  for (final v in rows.cast<List>()) {
    final told = _sabiin['${v[0]}:${v[1]}:${v[2]}'];
    if (told == null || v[3] != 1) continue;
    if (!RegExp(r'همز|^بالباء$').hasMatch('${v[6]}')) continue;
    while (v.length < 8) {
      v.add('');
    }
    v
      ..[4] = told.$1
      ..[5] = 'h'
      ..[6] = told.$2
      ..[7] = 'hamza_hadhf';
  }
  if (id == 'qalun' || id == 'warsh') return;
  // Abu Ja'far's bab of «مُسۡتَهۡزُونَ»: «وَيَحْذِفُ مُسْتَهْزُونَ وَالْبَابَ مَعْ تَطَوْا
  // يَطَوْا مُتَّكًا خَاطِيْنَ مُتَّكِئِي أُولا كَمُسْتَهْزِئِيْ مُنْشُونَ».
  final bab = RegExp(
    'تهزو|تهزي|طفوا|واطوا|تطو|متك|يتكو|خاطي|خطين|خاطو|خطو|مالو|نبو|منشو',
  );
  for (final v in rows.cast<List>()) {
    if (v[5] != 'h' ||
        !'${v[6]}'.contains('حذف الهمزة') ||
        v.length > 7 && '${v[7]}'.isNotEmpty ||
        !bab.hasMatch(_bare('${v[4]}').replaceAll(RegExp('[أإآٱ]'), 'ا'))) {
      continue;
    }
    while (v.length < 8) {
      v.add('');
    }
    v[7] = 'hamza_hadhf';
  }
}

/// «هُزُوٗا، كُفُوًا» with the hamza for the waw of Hafs, in their usul with
/// «ٱلنَّبِيٓءُ»: one row on the word, «بإبدال الواو همزة»; never in the farsh,
/// nor over the next word (Abu Ja'far's «هُزُؤًا أَهَذَا»).
void applyHuzuan(String id, Map quran, List rows) {
  if (!const {
    'qalun',
    'bazzi',
    'qunbul',
    'ibn_wardan',
    'ibn_jammaz',
    'warsh',
  }.contains(id)) {
    return;
  }
  final added = <List>[];
  for (final x in quran['ayahs'] as List) {
    for (final (w, word) in (x[4] as String).split(' ').indexed) {
      // Not «كُفُورٗا».
      if (!RegExp('^(هُزُو|كُفُو)[ًٗ]ا').hasMatch(word)) continue;
      final (s, a) = (x[0] as int, x[1] as int);
      final told = [
        for (final v in rows.cast<List>())
          if (v[0] == s &&
              v[1] == a &&
              (v[2] as int) <= w &&
              w < (v[2] as int) + (v[3] as num).toInt() &&
              RegExp('همز').hasMatch('${v[6]}') &&
              // Not Warsh's naql into it (هُزُوًا إِنَّ).
              !'${v[6]}'.startsWith('بنقل') &&
              !'${v.length > 7 ? v[7] : ''}'.startsWith('naql'))
            v,
      ];
      // Where the source tells it, or not (Abu Ja'far's الكهف 56): all six
      // read it so.
      told.forEach(rows.remove);
      added.add([
        s,
        a,
        w,
        1,
        word.replaceFirst(RegExp('(?<=^(هُزُ|كُفُ))و'), 'ؤ'),
        'h',
        'بإبدال الواو همزة',
        'hamza_zaida',
      ]);
    }
  }
  int order(List v) =>
      (v[0] as int) * 1000000 + (v[1] as int) * 1000 + (v[2] as int);
  for (final v in added) {
    final next = rows.indexWhere((o) => order(o as List) > order(v));
    rows.insert(next < 0 ? rows.length : next, v);
  }
}

void applyHamzaZaida(String id, Map quran, List rows) {
  applyHamzaHadhf(id, rows);
  applyHuzuan(id, quran, rows);
  if (!hamzaZaidaReaders.contains(id)) return;
  final words = <String, String>{
    for (final x in quran['ayahs'] as List)
      for (final (i, w) in (x[4] as String).split(' ').indexed)
        '${x[0]}:${x[1]}:$i': w,
  };
  final badal = {
    for (final v in rows.cast<List>())
      if (v.length > 7 && v[7] == 'badal') '${v[0]}:${v[1]}:${v[2]}',
  };
  for (final v in rows.cast<List>()) {
    final key = '${v[0]}:${v[1]}:${v[2]}';
    if (!_ofBab(words[key] ?? '') || !_told.hasMatch('${v[6]}')) continue;
    if (v.length > 7 && '${v[7]}'.isNotEmpty && v[7] != 'hamza_zaida') {
      continue;
    }
    var how = '${v[6]}'
        .replaceAll(RegExp(r'\s*(مع ثلاثة البدل|والمد)'), '')
        .replaceFirst('بإبدال الياء همزة', 'بالهمز')
        .trim();
    if (id == 'warsh' && badal.contains(key)) how = '$how مع ثلاثة البدل';
    while (v.length < 8) {
      v.add('');
    }
    v
      // On a kashida of its own after the hamza's (ٱلنَّبِيٓـِٕـۧنَ).
      ..[4] = '${v[4]}'.replaceAllMapped(
        RegExp('ـ([ِٕ]+)ۧ'),
        (m) => 'ـ${m[1]}ـۧ',
      )
      ..[5] = 'h'
      ..[6] = how
      ..[7] = 'hamza_zaida';
  }
}

void main() {
  final quran =
      jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
  for (final id in {
    ...hamzaZaidaReaders,
    'bazzi',
    'qunbul',
    'ibn_wardan',
    'ibn_jammaz',
  }) {
    final file = File('assets/data/qiraat/$id.json');
    final data = jsonDecode(file.readAsStringSync()) as Map;
    final before = jsonEncode(data);
    applyHamzaZaida(id, quran, data['variants'] as List);
    if (jsonEncode(data) != before) {
      file.writeAsStringSync(jsonEncode(data));
      stdout.writeln('Applied $id');
    }
  }
}
