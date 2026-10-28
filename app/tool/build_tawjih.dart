// Builds the offline book of tawjih (the reasons of the readings) from the
// OpenITI corpus (https://github.com/OpenITI; text of al-Maktaba
// al-Shamila): «حجة القراءات» of Abu Zur'a Ibn Zanjala (d. c. 403).
//
//   dart run tool/build_tawjih.dart <0403IbnZanjala.HujjatQiraat...-ara1>
//
// The book goes surah by surah; each passage is headed by the words it
// explains, often with their ayah ({مالك يوم الدين} 4), which are matched
// with the Hafs text to find the ayah.
//
// Output: assets/data/tafsir/90001.json.gz, in the form of the tafsir books
// (tool/build_tafsir.dart): {"id", "name", "author", "version", "texts",
// "ayahs": [[surah, ayah, text index], ...]}.
import 'dart:convert';
import 'dart:io';

const id = 90001;

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tool/build_tawjih.dart <openiti text>');
    exit(64);
  }
  final quran =
      jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
  // The Hafs words of each surah, with their ayah.
  final words = <int, List<(int, String)>>{};
  for (final a in quran['ayahs'] as List) {
    for (final w in (a[4] as String).split(' ')) {
      final s = skeleton(w);
      if (s.isNotEmpty) (words[a[0] as int] ??= []).add((a[1] as int, s));
    }
  }

  final passages = <({int surah, int ayah, List<String> paragraphs})>[];
  int? surah;
  var at = 0; // where the last passage was found in the surah's words
  List<String>? paragraphs;

  void open(String quote, int? number) {
    final s = surah;
    if (s == null) return;
    // In this surah; else in the next ones, whose heading the book lacks
    // (سورة النساء).
    var found = find(words[s]!, quote, at, number);
    var to = s;
    for (var next = s + 1; found == null && next <= s + 3; next++) {
      if (next > 114) break;
      found = find(words[next]!, quote, 0, number);
      to = next;
    }
    if (found == null) {
      // Not found: the words are of the passage before.
      paragraphs?.add('﴿$quote﴾');
      return;
    }
    surah = to;
    at = found.$2;
    paragraphs = ['﴿$quote﴾'];
    passages.add((surah: to, ayah: found.$1, paragraphs: paragraphs!));
  }

  final surahHead = RegExp(r'^### \$ (\d+) -');
  final heading = RegExp(
    r'^(?:### \|\s*(?:سورة [^{]*)?|#)\s*(?:بسم الله الرحمن الرحيم\s*)?'
    r'\{([^}]+)\}(.*)$',
  );
  final numbers = RegExp(r'^[\d\sو]*$');
  for (var line in File(args[0]).readAsLinesSync()) {
    line = line.replaceAll(RegExp(r'\s*ms\d+\s*'), ' ').trimRight();
    if (line.startsWith('#META#') || line.contains('OpenITI#')) continue;
    final head = surahHead.firstMatch(line);
    if (head != null) {
      surah = int.parse(head[1]!);
      at = 0;
      paragraphs = null;
      // The surah's first passage may be headed on the same line.
      final q = RegExp(r'\{([^}]+)\}([^{}]*)$').firstMatch(line);
      if (q != null) open(q[1]!.trim(), firstNumber(q[2]!));
      continue;
    }
    if (RegExp(r'^# PageV\d+P\d+').hasMatch(line) ||
        RegExp(r'^#\s*[\d\s]+$').hasMatch(line)) {
      continue;
    }
    // A heading: the words explained, alone on the line or with the ayah's
    // number ({مالك يوم الدين} 4، 5 و 6).
    final q = heading.firstMatch(line);
    if (q != null && (line.startsWith('###') || numbers.hasMatch(q[2]!))) {
      open(q[1]!.trim(), firstNumber(q[2]!));
      continue;
    }
    if (line.startsWith('###')) continue; // numbering of a list
    final text = tidy(line.replaceFirst(RegExp(r'^(#|~~)\s*'), ''));
    // A passage the book does not head: «قرأ ابن عامر وأبو بكر {وسيصلون
    // سعيرا}» (4:10) after 4:5, the words of a later ayah of the surah.
    final reading = RegExp(
      r'^#\s*(?:و)?قر[أا] [^{]*\{([^}]+)\}',
    ).firstMatch(line);
    final s = surah;
    if (reading != null && s != null && passages.isNotEmpty) {
      final last = passages.last;
      final found = find(words[s]!, reading[1]!.trim(), at, null);
      if (last.surah == s &&
          found != null &&
          found.$1 > last.ayah &&
          found.$2 > at) {
        at = found.$2;
        paragraphs = ['﴿${reading[1]!.trim()}﴾'];
        passages.add((surah: s, ayah: found.$1, paragraphs: paragraphs!));
      }
    }
    if (text.isEmpty || paragraphs == null) continue;
    if (line.startsWith('~~') && paragraphs!.length > 1) {
      paragraphs![paragraphs!.length - 1] += ' $text';
    } else {
      paragraphs!.add(text);
    }
  }

  // A passage per ayah; several passages of one ayah together.
  final byAyah = <int, List<String>>{};
  for (final p in passages) {
    if (p.paragraphs.length < 2) continue;
    (byAyah[p.surah * 1000 + p.ayah] ??= []).add(p.paragraphs.join('\n'));
  }
  final texts = <String>[];
  final ayahs = <List<int>>[];
  for (final k in byAyah.keys.toList()..sort()) {
    ayahs.add([k ~/ 1000, k % 1000, texts.length]);
    texts.add(byAyah[k]!.join('\n\n'));
  }
  final out = File('assets/data/tafsir/$id.json.gz');
  out.writeAsBytesSync(
    gzip.encode(
      utf8.encode(
        jsonEncode({
          'id': id,
          'name': 'حجة القراءات',
          'author': 'ابن زنجلة',
          'version': 'OpenITI ${args[0].split(RegExp(r'[\\/]')).last}',
          'texts': texts,
          'ayahs': ayahs,
        }),
      ),
    ),
  );
  stdout.writeln(
    '${passages.length} passages, ${ayahs.length} ayahs, '
    '${{for (final a in ayahs) a[0]}.length} surahs, '
    '${(out.lengthSync() / 1024).round()} KB',
  );
}

int? firstNumber(String text) =>
    int.tryParse(RegExp(r'\d+').firstMatch(text)?[0] ?? '');

/// The ayah where [quote] begins, searched from [from] in the surah's
/// words (then from its start), with the index after it; at ayah [number]
/// first, when the book gives it.
(int, int)? find(
  List<(int, String)> words,
  String quote,
  int from,
  int? number,
) {
  final q = [
    for (final w in quote.split(RegExp(r'\s+')))
      if (skeleton(w).isNotEmpty) skeleton(w),
  ];
  if (q.isEmpty) return null;
  final n = q.length < 3 ? q.length : 3;
  for (final (start, only) in [
    if (number != null) (0, number),
    (from, null),
    (0, null),
  ]) {
    for (var i = start; i + n <= words.length; i++) {
      if (only != null && words[i].$1 != only) continue;
      var ok = true;
      for (var k = 0; k < n && ok; k++) {
        ok = words[i + k].$2 == q[k];
      }
      if (ok) return (words[i].$1, i + n);
    }
  }
  return null;
}

/// The letters compared: no vowels, and none of the letters the Uthmani
/// and the common spelling write differently.
String skeleton(String word) => word
    .replaceAll(
      RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]'),
      '',
    )
    .replaceAll(RegExp('[أإآؤئ]'), 'ء')
    .replaceAll('ة', 'ه')
    .replaceAll(RegExp('[اٱويى]'), '')
    .replaceAll(RegExp('[^ء-ي]'), '');

/// A line of the book: its quotations of the Quran in ﴿ ﴾, of words in « ».
String tidy(String line) => line
    .replaceAllMapped(RegExp(r'\{([^}]+)\}'), (m) => '﴿${m[1]!.trim()}﴾')
    .replaceAllMapped(RegExp(r'/\s*([^/]+?)\s*/'), (m) => '«${m[1]}»')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
