// Builds the offline files of the twelve riwayat that have no KFGQPC text,
// from Quranpedia's official qiraat dump.
//
//   dart run tool/build_quranpedia.dart <qiraat.json.gz | qiraat.json>
//
// The dump is https://quranpedia.net/dumps/qiraat.json.gz (licence:
// https://quranpedia.net/dumps/LICENSE.md — free to use inside apps; a
// republished copy credits Quranpedia.net and states the dump version, which
// is written into every output file). Run it again with a newer dump to take
// in Quranpedia's corrections.
//
// Input:  assets/data/quran.json (the Hafs base text, from build_data.dart)
// Output: assets/data/qiraat/<riwaya>.json, in the format of the KFGQPC
//         riwayat (see VariantRepository).
import 'dart:convert';
import 'dart:io';

import 'package:qiraat_mushaf/data/quranpedia_qiraat.dart';
import 'package:qiraat_mushaf/models/quran.dart';

/// The riwayat taken from Quranpedia; the others come from KFGQPC texts.
const riwayat = [
  'hisham', 'ibn_dhakwan', 'khalaf_hamzah', 'khallad', 'abul_harith', //
  'duri_kisai', 'ibn_wardan', 'ibn_jammaz', 'ruways', 'rawh', 'ishaq',
  'idris',
];

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln(
      'usage: dart run tool/build_quranpedia.dart <qiraat.json.gz>',
    );
    exit(64);
  }
  final bytes = File(args[0]).readAsBytesSync();
  final dump = jsonDecode(
    utf8.decode(args[0].endsWith('.gz') ? gzip.decode(bytes) : bytes),
  ) as Map<String, dynamic>;
  final version = (dump['license'] as Map)['version'] as String;

  final ayahs = <(int, int), Ayah>{
    for (final a
        in (jsonDecode(File('assets/data/quran.json').readAsStringSync())
                as Map<String, dynamic>)['ayahs']
            as List)
      (a[0] as int, a[1] as int): Ayah(
        surah: a[0] as int,
        number: a[1] as int,
        page: a[2] as int,
        juz: a[3] as int,
        words: (a[4] as String).split(' '),
      ),
  };

  final out = {for (final id in riwayat) id: <List<Object>>[]};
  final unmatched = <String>[];
  final moved = <String>[];
  for (final entry in dump['data'] as List) {
    final ayah = ayahs[(entry['surah'] as int, entry['ayah'] as int)]!;
    List<Variant> convert(
      Ayah ayah,
      Object? json, {
      void Function(Object entry)? unmatched,
    }) => QuranpediaQiraat.convert(
      ayah,
      json,
      previous: ayahs[(ayah.surah, ayah.number - 1)],
      next: ayahs[(ayah.surah, ayah.number + 1)],
      unmatched: unmatched,
    );
    final variants = convert(
      ayah,
      entry['qiraat'],
      unmatched: (e) {
        // A few entries are filed under the ayah before or after theirs.
        for (final n in [ayah.number + 1, ayah.number - 1]) {
          final next = ayahs[(ayah.surah, n)];
          if (next == null) continue;
          var found = true;
          final vs = convert(next, [e], unmatched: (_) => found = false);
          if (!found) continue;
          moved.add(
            '${ayah.surah}:${ayah.number} → $n ${(e as Map)['ayah_word']}',
          );
          for (final v in vs) {
            out[v.riwayaId]?.add(_row(v));
          }
          return;
        }
        unmatched.add(
          '${ayah.surah}:${ayah.number} ${(e as Map)['ayah_word']}',
        );
      },
    );
    for (final v in variants) {
      out[v.riwayaId]?.add(_row(v));
    }
  }

  for (final MapEntry(key: id, value: variants) in out.entries) {
    variants.sort((a, b) {
      for (var i = 0; i < 3; i++) {
        final c = (a[i] as int).compareTo(b[i] as int);
        if (c != 0) return c;
      }
      return 0;
    });
    File('assets/data/qiraat/$id.json').writeAsStringSync(
      jsonEncode({
        'riwaya': id,
        'source':
            'Quranpedia.net qiraat dump $version — https://quranpedia.net',
        'variants': variants,
      }),
    );
    stdout.writeln('$id.json: ${variants.length} variants');
  }
  stdout.writeln(
    'dump $version: ${(dump['data'] as List).length} ayahs, '
    '${moved.length} words placed in a neighbouring ayah, '
    '${unmatched.length} not found in the Hafs text:',
  );
  unmatched.forEach(stdout.writeln);
  stdout.writeln('Placed in a neighbouring ayah:');
  moved.forEach(stdout.writeln);
}

List<Object> _row(Variant v) => [
  v.surah, v.ayah, v.word, v.count, v.text, v.kind.code, //
  if (v.description.isNotEmpty) v.description,
];
