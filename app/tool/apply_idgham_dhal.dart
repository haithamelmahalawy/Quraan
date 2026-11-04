// «إدغام الذال في التاء» of اتخذ and أخذ (ٱتَّخَذۡتُمُ، أَخَذۡتُهُمۡ): one rule
// of the idgham saghir, told on its word alone (not «قل أتخذتم»), never in
// the farsh. Ibn Kathir, Hafs and Ruways read it with izhar, as Hafs.
// Run from app/: dart run tool/apply_idgham_dhal.dart
import 'dart:convert';
import 'dart:io';

/// Those who read it with idgham.
const idghamDhalReaders = {
  'shubah',
  'qalun',
  'ibn_wardan',
  'ibn_jammaz',
  'warsh',
  'hisham',
  'ibn_dhakwan',
  'rawh',
};

/// The words of Hafs's text where the dhal of اتخذ or أخذ meets the ta.
List<(int, int, int, String)> idghamDhalSites(Map quran) => [
  for (final x in quran['ayahs'] as List)
    for (final (i, w) in (x[4] as String).split(' ').indexed)
      if (w.contains('خَذۡت')) (x[0] as int, x[1] as int, i, w),
];

/// What a word reads: its letters and vowels, without the idgham's shadda
/// and sukun, the silah, the wasl's signs or the stops.
String _reading(String t) => t
    .replaceAll(RegExp('[ّْۡۥ۪ٓ۬ۖ-ۜ]'), '')
    .replaceAll(RegExp('[ٱأإ]'), 'ا')
    .replaceFirstMapped(RegExp('^((?:اَ)?[وف]?َ?)ا[َُِ]'), (m) => '${m[1]}ا')
    .replaceFirst(RegExp(r'مُ$'), 'م');

final _told = RegExp(r'(،\s*|\s+و|^)ب?(إدغام الذال في التاء|تشديد التاء)');

/// Tells it in [rows] of [id] as one usul row a word, in place of the farsh
/// and the rows over two words the sources gave.
void applyIdghamDhal(String id, Map quran, List rows) {
  if (!idghamDhalReaders.contains(id)) return;
  final added = <List>[];
  for (final (s, a, w, word) in idghamDhalSites(quran)) {
    bool at(List v, int d) => v[0] == s && v[1] == a && v[2] == w - d;
    bool silah(List v) => '${v[6]}'.trim() == 'بصلة ميم الجمع';
    // Told here, or over the word before and this one (قل أتخذتم).
    final told = [
      for (final v in rows.cast<List>())
        if ((at(v, 0) || at(v, 1) && (v[3] as num) > 1) &&
            (v.length > 7 && v[7] == 'idgham_saghir' ||
                _told.hasMatch('${v[6]}')))
          v,
    ];
    final meta = <String, Object?>{};
    var text = '';
    var hasSilah = false;
    for (final v in told) {
      rows.remove(v);
      final own = '${v[4]}'.split(' ');
      final mine = at(v, 0)
          ? own.first
          : own.length > 1
          ? own[1]
          : '';
      final rest = '${v[6]}'
          .trim()
          .replaceAll(_told, '')
          .replaceFirst(RegExp(r'^\s*و'), '')
          .trim();
      if (rest.isNotEmpty && at(v, 0)) {
        if (rest.replaceFirst(RegExp('^ب'), '') == 'صلة ميم الجمع') {
          hasSilah = true;
        } else if (_reading(mine) != _reading(word)) {
          // A farsh of the word with it (لَتَخِذتَّ): in the farsh.
          added.add([
            s,
            a,
            w,
            1,
            mine,
            'f',
            rest.startsWith('ب') ? rest : 'ب$rest',
            '',
            if (v.length > 8) v[8],
          ]);
          continue;
        }
      }
      if (v.length > 8 && v[8] is Map) meta.addAll((v[8] as Map).cast());
      // Its letters, the dhal kept (not أَخَتُّمُۥ).
      if (text.isEmpty && _reading(mine) == _reading(word)) text = mine;
    }
    // His silah told apart: written in this row, its own left bare.
    for (final v in rows.cast<List>()) {
      if (at(v, 0) && silah(v)) {
        hasSilah = true;
        v[4] = '';
      }
    }
    if (hasSilah &&
        !rows.cast<List>().any((v) => at(v, 0) && silah(v)) &&
        !added.any((v) => at(v, 0) && silah(v))) {
      added.add([s, a, w, 1, '', 'u', 'بصلة ميم الجمع', '']);
    }
    // Hafs's word with it, where the source writes none or writes it bare
    // (قلْ أتَّخَذتُّمُ).
    final asHafs = word.replaceFirstMapped(
      RegExp('ذۡت([َُِ])'),
      (m) => 'ذت${m[1]}ّ',
    );
    int vowels(String t) =>
        RegExp('[ًٌٍَُِ]').allMatches(t.replaceAll('ُۥ', '')).length;
    if (text.isEmpty ||
        vowels(text) < vowels(asHafs) ||
        RegExp('^[أإ](?![َُِ])').hasMatch(text) ||
        // Its dhal with a sukun, though merged (لَتَّخَذْتَّ).
        RegExp('ذ[ْۡ]ت').hasMatch(text)) {
      text = asHafs;
    }
    if (hasSilah && !text.contains('ۥ')) {
      text = text.replaceFirstMapped(
        RegExp(r'مُ?ۡ?([ۖ-ۜ]*)$'),
        (m) => 'مُۥ${m[1]}',
      );
    }
    // Another row writes the word (his naql, a farsh): this one tells it.
    final written = [
      ...rows.cast<List>(),
      ...added,
    ].any((v) => at(v, 0) && !silah(v) && '${v[4]}'.isNotEmpty);
    added.add([
      s,
      a,
      w,
      1,
      written ? '' : text,
      'u',
      'بإدغام الذال في التاء',
      'idgham_saghir',
      if (meta.isNotEmpty) meta,
    ]);
  }
  // In the order of the words, after the rows already there.
  int order(List v) =>
      (v[0] as int) * 1000000 + (v[1] as int) * 1000 + (v[2] as int);
  for (final v in added) {
    final next = rows.indexWhere((o) => order(o as List) > order(v));
    rows.insert(next < 0 ? rows.length : next, v);
  }
}

void main() {
  final quran =
      jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
  for (final id in idghamDhalReaders) {
    final file = File('assets/data/qiraat/$id.json');
    final data = jsonDecode(file.readAsStringSync()) as Map;
    final before = jsonEncode(data);
    applyIdghamDhal(id, quran, data['variants'] as List);
    if (jsonEncode(data) != before) {
      file.writeAsStringSync(jsonEncode(data));
      stdout.writeln('Applied $id');
    }
  }
}
