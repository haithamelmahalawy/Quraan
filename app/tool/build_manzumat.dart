// Builds the text of the two poems the riwayat are read by: the Shatibiyya
// (حرز الأماني، the seven qiraat) and the Durrah (الدرة المضية، Abu Ja'far,
// Ya'qub, Khalaf al-'Ashir), verse by verse with their chapters, from
// Quranpedia's books 127 and 126 (licence https://quranpedia.net/dumps/LICENSE.md:
// free to use inside apps; credited in the file).
//
//   curl -o book-127.json https://quranpedia.net/books-contents/book-127.json
//   curl -o book-126.json https://quranpedia.net/books-contents/book-126.json
//   dart run tool/build_manzumat.dart <dir with book-127.json and book-126.json>
//
// Output: assets/data/manzumat.json
//   {"source": ..., "shatibiyya": [[n, chapter, sadr, ajz], ...], "durrah": [...]}
import 'dart:convert';
import 'dart:io';

int arabicNumber(String s) =>
    int.parse(s.replaceAllMapped(RegExp('[٠-٩]'), (m) => '${m[0]!.codeUnitAt(0) - 0x0660}'));

String clean(String s) => s
    .replaceAll(RegExp('<[^>]+>'), '')
    .replaceAll('\r', '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// The verses of a book's text, each in the chapter whose heading comes
/// before it: «سُوْرَةُ الْبَقَرَةِ (١٠١)», «بَابُ فَرْشِ الْحُرُوفِ (٦٧٦) :».
List<List<Object>> verses(
  Map<String, dynamic> book,
  String firstChapter, {
  bool numberedHeadings = false,
}) {
  final text = [for (final c in book['contents'] as List) c['text'] as String].join('\n');
  // One line per verse or heading.
  final lines = text
      .replaceAllMapped(
        RegExp(r'<tr><td>\s*([٠-٩]+)\s*-\s*([\s\S]*?)</td><td>([\s\S]*?)</td></tr>'),
        (m) => '\n@${m[1]}|${clean(m[2]!)}|${clean(m[3]!)}\n',
      )
      .replaceAll(RegExp('<br ?/?>|</p>|</table>|<table[^>]*>'), '\n')
      .split(RegExp('[\r\n]+'));
  final out = <List<Object>>[];
  var chapter = firstChapter;
  final seen = <int>{};
  for (final raw in lines) {
    final line = clean(raw);
    if (line.isEmpty || line.startsWith('*')) continue;
    // A verse from a table row.
    if (line.startsWith('@')) {
      final [n, sadr, ajz] = line.substring(1).split('|');
      if (seen.add(arabicNumber(n))) out.add([arabicNumber(n), chapter, sadr, ajz]);
      continue;
    }
    // A numbered heading (the Durrah only), shorter than any verse:
    // «٢ - بَابُ الْبَسْمَلَةِ وَأُمِّ الْقُرْآنِ ٤», «٤ - هَاءُ الْكِنَايَةِ»,
    // «١٦ - بَابُ فَرْشِ الْحُرُوفِ:».
    final numbered =
        RegExp(r'^[٠-٩]+\s*-\s*(.+?)\s*[:]?\s*[٠-٩]*\s*[:]?$').firstMatch(line);
    if (numberedHeadings && numbered != null && numbered[1]!.length < 100) {
      chapter = numbered[1]!.trim();
      continue;
    }
    // A verse on one line: «٤٤٤ - صدر... عجز» (halves split by «......»
    // or near the middle).
    final one = RegExp(r'^([٠-٩]+)\s*-\s*(.+)$').firstMatch(line);
    if (one != null) {
      final n = arabicNumber(one[1]!);
      final body = one[2]!;
      final halves = body.split(RegExp(r'\s*\.{3,}\s*'));
      final (sadr, ajz) = halves.length == 2
          ? (halves[0], halves[1])
          : _split(body);
      if (seen.add(n)) out.add([n, chapter, sadr.trim(), ajz.trim()]);
      continue;
    }
    // A heading: a line ending with the number of its verses, in brackets
    // or not («سُوْرَةُ الْبَقَرَةِ (١٠١)», «سُوْرَةُ الْبَقَرَةِ ٢٤»).
    final heading = RegExp(r'^(.+?)\s*\(?([٠-٩]+)\)?\s*:?$').firstMatch(line);
    if (heading != null) chapter = heading[1]!.trim();
  }
  out.sort((a, b) => (a[0] as int).compareTo(b[0] as int));
  return out;
}

/// A verse written on one line: its two halves, split between the words
/// where they are closest in length.
(String, String) _split(String body) {
  final words = body.split(' ');
  var best = 1, gap = body.length;
  for (var i = 1; i < words.length; i++) {
    final d = (words.take(i).join(' ').length - words.skip(i).join(' ').length).abs();
    if (d < gap) (best, gap) = (i, d);
  }
  return (words.take(best).join(' '), words.skip(best).join(' '));
}

void main(List<String> args) {
  final dir = args.isEmpty ? '.' : args[0];
  Map<String, dynamic> read(int id) =>
      jsonDecode(File('$dir/book-$id.json').readAsStringSync()) as Map<String, dynamic>;
  final shatibiyya = verses(read(127), 'المقدمة');
  final durrah = verses(read(126), 'المقدمة', numberedHeadings: true);
  for (final (name, list, total) in [('shatibiyya', shatibiyya, 1173), ('durrah', durrah, 241)]) {
    final have = {for (final v in list) v[0]};
    final missing = [for (var n = 1; n <= total; n++) if (!have.contains(n)) n];
    stdout.writeln('$name: ${list.length} verses, '
        '${{for (final v in list) v[1]}.length} chapters, missing $missing');
  }
  File('assets/data/manzumat.json').writeAsStringSync(jsonEncode({
    'source': 'الموسوعة القرآنية quranpedia.net: حرز الأماني (كتاب 127) '
        'والدرة المضية (كتاب 126)',
    'shatibiyya': shatibiyya,
    'durrah': durrah,
  }));
}
