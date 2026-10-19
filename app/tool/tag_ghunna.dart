// Tags the readings of Khalaf that differ from Hafs only by his idgham
// without ghunna in the waw and the ya (rule 'ghunna'): the page shows them
// as Hafs; the readings of the word still tell of them.
//
//   dart run tool/tag_ghunna.dart <qiraat.json.gz>
//
// The dump is https://quranpedia.net/dumps/qiraat.json.gz, as for
// tool/build_quranpedia.dart. Run after it, then tool/build_usul.dart.
import 'dart:convert';
import 'dart:io';

String _norm(String t) => t
    .replaceAll(RegExp(r'بلا\s+غنة'), 'بغنة')
    .replaceAll(RegExp('[ً-ْ\s]'), '');

/// The words in brackets, as written.
String? _quoted(String t) => RegExp(r'\(([^)]*)\)').firstMatch(t)?[1]?.trim();

/// Written exactly as Hafs, the ghunna aside, with nothing else told that
/// the writing does not show (the source words some descriptions of Hafs's
/// own reading differently: ترقيق الراء / ترقيق اللام).
bool _sameWords(String text, String hafs) {
  final words = _quoted(text);
  return words != null &&
      words.isNotEmpty &&
      words == _quoted(hafs) &&
      text.contains('بلا غنة') &&
      !RegExp('سكت|مال|تقليل|مد |المد|حركات|تسهيل|إبدال|ابدال|نقل|صلة')
          .hasMatch(text);
}

void main(List<String> args) {
  final bytes = File(args.single).readAsBytesSync();
  final dump = jsonDecode(
    utf8.decode(args.single.endsWith('.gz') ? gzip.decode(bytes) : bytes),
  ) as Map<String, dynamic>;

  // Where Khalaf reads as Hafs but for the ghunna: the ayah and his reading.
  final likeHafs = <String, List<String>>{};
  for (final e in dump['data'] as List) {
    for (final w in e['qiraat'] as List) {
      final groups = (w['qiraat'] as List).cast<Map>();
      bool reads(Map q, String name) =>
          (q['rewayat'] as List).any((r) => r['rawi']['name'] == name);
      final hafs = groups.where((q) => reads(q, 'حفص')).firstOrNull;
      if (hafs == null) continue;
      for (final q in groups) {
        final text = q['qiraa_text'] as String;
        if (q == hafs || !reads(q, 'خلف') || !text.contains('غنة')) continue;
        if (_norm(text) == _norm(hafs['qiraa_text'] as String) ||
            _sameWords(text, hafs['qiraa_text'] as String)) {
          likeHafs.putIfAbsent('${e['surah']}:${e['ayah']}', () => []).add(text);
        }
      }
    }
  }

  final file = File('assets/data/qiraat/khalaf_hamzah.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  var tagged = 0;
  for (final v in json['variants'] as List) {
    final texts = likeHafs['${v[0]}:${v[1]}'];
    if (texts == null || v.length < 7 || v.length > 7) continue;
    final description = _norm(v[6] as String);
    if (description.isEmpty) continue;
    if (texts.any((t) => _norm(t).contains(description))) {
      (v as List).add('ghunna');
      tagged++;
    }
  }
  file.writeAsStringSync(jsonEncode(json));
  stdout.writeln('khalaf_hamzah: $tagged readings tagged ghunna '
      '(${likeHafs.values.fold(0, (n, l) => n + l.length)} in the dump)');
}
