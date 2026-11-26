// The usul and farsh of Abu 'Amr (al-Duri, al-Susi): see abuamr_usul.dart.
// Rerunning gives the same file.
//   dart run tool/build_abuamr_usul.dart
import 'dart:convert';
import 'dart:io';

import 'build_ashab_usul.dart' hide main;

void main() {
  final quran =
      jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
  String read(String id) =>
      File('assets/data/qiraat/$id.json').readAsStringSync();
  List<List> rows(String id) =>
      ((jsonDecode(read(id)) as Map)['variants'] as List).cast<List>();
  final sources = AshabSources.load(read);
  final book =
      jsonDecode(File('assets/data/kharouf.json').readAsStringSync()) as Map;
  final duriKisai = rows('duri_kisai'), khallad = rows('khallad');
  for (final id in abuAmrRiwayat) {
    final raw =
        jsonDecode(File('tool/abuamr_raw/$id.json').readAsStringSync()) as Map;
    final data = {...raw};
    final counts = buildAbuAmrUsul(
      quran,
      data,
      id,
      sources,
      raw: (raw['variants'] as List).cast<List>(),
      book: book,
      duriKisai: duriKisai,
      khallad: khallad,
    );
    stdout.writeln('$id: $counts');
    File('assets/data/qiraat/$id.json').writeAsStringSync(jsonEncode(data));
  }
}
