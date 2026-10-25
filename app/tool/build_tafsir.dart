// Builds the offline tafsir books and the list of reciters from Quranpedia's
// official dumps (https://quranpedia.net/dumps; licence
// https://quranpedia.net/dumps/LICENSE.md: free to use inside apps; a copy
// credits Quranpedia.net and states the dump version, written into each
// file).
//
//   dart run tool/build_tafsir.dart <dumpDir>
//
// <dumpDir> holds tafsir-book-<id>.json.gz for the books below and
// reciters-index.json.gz.
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
  for (final id in offline) {
    final dump = read('tafsir-book-$id.json.gz');
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
      'tafsir $id ${book['name']}: ${ayahs.length} ayahs, '
      '${texts.length} texts, ${(out.length / 1e6).toStringAsFixed(1)} MB',
    );
  }

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
