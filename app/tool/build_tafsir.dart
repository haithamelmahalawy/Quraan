// Builds the offline tafsir books and the list of reciters from Quranpedia's
// official dumps (https://quranpedia.net/dumps; licence
// https://quranpedia.net/dumps/LICENSE.md: free to use inside apps; a copy
// credits Quranpedia.net and states the dump version, written into each
// file).
//
//   dart run tool/build_tafsir.dart <dumpDir>
//
// <dumpDir> holds tafsir-book-<id>.json.gz and e3rab-book-<id>.json.gz for
// the books below and reciters-index.json.gz; what it lacks is left as it is.
//
// Output:
//   assets/data/tafsir/<id>.json.gz  {"id", "name", "author", "version",
//       "texts": [...], "ayahs": [[surah, ayah, text index], ...]}; a text
//       explaining several ayahs is stored once.
//   assets/data/reciters.json        {"version", "riwayat": {riwaya id:
//       [{"id", "name", "server"}]}}: recitations recorded ayah by ayah,
//       played from <server><sss><aaa>.mp3.
import 'dart:convert';
import 'dart:io';

import 'package:qiraat_mushaf/data/quranpedia_qiraat.dart';
import 'package:qiraat_mushaf/data/tafsir_text.dart';

/// The books stored in the app: short and widely read.
const offline = [2012, 2003, 272, 3, 2013];

/// The books of i'rab stored in the app: the whole Quran word by word
/// (al-Da'as), and al-Kharrat's short one.
const offlineE3rab = [316, 180];

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tool/build_tafsir.dart <dumpDir>');
    exit(64);
  }
  final dir = args[0];
  Map<String, dynamic> read(String name) =>
      jsonDecode(utf8.decode(gzip.decode(File('$dir/$name').readAsBytesSync())))
          as Map<String, dynamic>;

  Directory('assets/data/tafsir').createSync(recursive: true);
  for (final (kind, id) in [
    for (final id in offline) ('tafsir', id),
    for (final id in offlineE3rab) ('e3rab', id),
  ]) {
    if (!File('$dir/$kind-book-$id.json.gz').existsSync()) continue;
    final dump = read('$kind-book-$id.json.gz');
    final book = dump['book'] as Map;
    final texts = <String>[];
    final index = <String, int>{};
    final ayahs = <List<int>>[];
    for (final a in dump['ayahs'] as List) {
      final text = [
        for (final c in (a['content'] as List? ?? const []))
          tafsirText(c['text'] as String? ?? ''),
      ].where((t) => t.isNotEmpty).join('\n\n');
      if (text.isEmpty) continue;
      final i = index.putIfAbsent(text, () {
        texts.add(text);
        return texts.length - 1;
      });
      ayahs.add([a['surah'] as int, a['ayah'] as int, i]);
    }
    final out = gzip.encode(
      utf8.encode(
        jsonEncode({
          'id': id,
          'name': book['short_name'] ?? book['name'],
          'author': (book['author'] as Map?)?['ar_name'],
          'version': (dump['license'] as Map)['version'],
          'texts': texts,
          'ayahs': ayahs,
        }),
      ),
    );
    File('assets/data/tafsir/$id.json.gz').writeAsBytesSync(out);
    stdout.writeln(
      '$kind $id ${book['name']}: ${ayahs.length} ayahs, '
      '${texts.length} texts, ${(out.length / 1e6).toStringAsFixed(1)} MB',
    );
  }

  if (!File('$dir/reciters-index.json.gz').existsSync()) return;
  final reciters = read('reciters-index.json.gz');
  final byRiwaya = <String, List<Map<String, Object?>>>{};
  for (final r in (reciters['data'] as List).expand((x) => x as List)) {
    // Recorded ayah by ayah, for the whole Quran.
    if ((r['classification'] as Map)['id'] != 2) continue;
    if ((r['surahs_list'] as List).length != 114) continue;
    final riwaya = QuranpediaQiraat.riwayaOf[(r['rawi'] as Map)['id']];
    if (riwaya == null) continue;
    var server = r['server'] as String;
    if (!server.endsWith('/')) server += '/';
    (byRiwaya[riwaya] ??= []).add({
      'id': r['id'],
      'name': _reciterName(r['name'] as String),
      'server': server,
      if (r['id'] == 268) 'numbering': 'makki-6220',
      'ends': ?clipEnds[r['id']],
    });
  }
  File('assets/data/reciters.json').writeAsStringSync(
    jsonEncode({
      'version': (reciters['license'] as Map)['version'],
      'riwayat': byRiwaya,
    }),
  );
  for (final MapEntry(:key, :value) in byRiwaya.entries) {
    stdout.writeln('reciters $key: ${value.length}');
  }
}

/// "مصحف إبراهيم الأخضر برواية حفص عن عاصم" → "إبراهيم الأخضر".
String _reciterName(String name) => name
    .replaceFirst(RegExp(r'^مصحف\s+'), '')
    .replaceFirst(RegExp(r'\s+برواية.*$'), '')
    .trim();

/// Files of a recitation that run on past their ayah into the ayat after it,
/// and where the ayah ends in them (ms): found by the pauses of the file and
/// the voice of the next file heard in it.
const clipEnds = <int, Map<String, int>>{
  // مفتاح السلطاني: ابن ذكوان، هشام، ابن وردان، ابن جماز.
  274: {'2:5': 14000, '6:10': 13680, '20:40': 17320},
  273: {'6:10': 13680},
  282: {'11:9': 14140, '12:71': 6480},
  283: {'11:9': 14140, '12:71': 6480},
};
