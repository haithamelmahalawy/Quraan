// Builds the offline book of stopping and starting (الوقف والابتداء) from
// the OpenITI corpus (https://github.com/OpenITI; text of al-Maktaba
// al-Shamila): «المكتفى في الوقف والابتدا» of Abu 'Amr al-Dani (d. 444).
//
//   dart run tool/build_waqf.dart <0444AbuCamrDani.MuktafiFiWaqf...-ara1>
//
// The book goes surah by surah, judging each stop where the quoted words
// end ({لا ريب فيه} كاف). A paragraph often judges several stops of several
// ayahs, so it is cut at each quotation, and each part goes to the ayah of
// its quotation's last word, found in order in the Hafs text. A quotation
// not found ahead in the surah (an example from elsewhere) stays with the
// part before it.
//
// Output: assets/data/tafsir/90002.json.gz, in the form of the tafsir books
// (tool/build_tafsir.dart): {"id", "name", "author", "version", "texts",
// "ayahs": [[surah, ayah, text index], ...]}.
import 'dart:convert';
import 'dart:io';

import 'build_tawjih.dart' show skeleton, tidy;

const id = 90002;

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tool/build_waqf.dart <openiti text>');
    exit(64);
  }
  final quran =
      jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
  final words = <int, List<(int, String)>>{};
  for (final a in quran['ayahs'] as List) {
    for (final w in (a[4] as String).split(' ')) {
      final s = skeleton(w);
      if (s.isNotEmpty) (words[a[0] as int] ??= []).add((a[1] as int, s));
    }
  }

  // The book's paragraphs, by surah heading.
  final paragraphs = <(int, String)>[];
  var surah = 0;
  for (var line in File(args[0]).readAsLinesSync()) {
    line = line.replaceAll(RegExp(r'\s*ms\d+\s*'), ' ').trimRight();
    if (line.startsWith('#META#') || line.contains('OpenITI#')) continue;
    if (line.startsWith('### |')) {
      // The introduction's chapters come before the Fatiha (أم القرآن).
      if (line.contains('سورة')) surah++;
      continue;
    }
    if (surah == 0) continue;
    if (RegExp(r'^# PageV\d+P\d+').hasMatch(line)) continue;
    final text = line.replaceFirst(RegExp(r'^(#|~~)\s*'), '');
    if (text.trim().isEmpty) continue;
    if (line.startsWith('~~') && paragraphs.isNotEmpty) {
      final (s, t) = paragraphs.removeLast();
      paragraphs.add((s, '$t $text'));
    } else {
      paragraphs.add((surah, text));
    }
  }

  // Each part of a paragraph to the ayah where its quotation ends.
  final quote = RegExp(r'\{([^}]+)\}|\(\(([^)]+)\)\)');
  final verdict = RegExp(
    r'^\s*[.،,]?\s*(?:و)?(?:تام|كاف|حسن|أكفى|أتم|أحسن|قبيح|صالح|جائز|'
    r'ليس بتام|ليس بوقف|لا يوقف|لا يتم|وقف|مثله|كذلك|نظيره|التمام)',
  );
  final leadIn = RegExp(r'(?:و?(?:الوقف )?على|ثم|ومثله|وكذلك|ونظيره)(?: قوله)?:?\s*$');
  // … ومثله {جرزا}: a stop judged as the one before it.
  final likeBefore = RegExp(r'(?:ومثله|وكذلك|ونظيره)\s*$');
  final byAyah = <int, List<String>>{};
  var current = 0; // the surah the text is at (al-Munafiqun has no heading)
  var at = 0;
  var last = 0; // the key of the last ayah given a part
  var heading = 0;
  // The last verdict given, for a stop said to be like it (ومثله {…}).
  var judgement = '';
  final judgedAs = RegExp(
    r'[﴾»]\s*[.،]?\s*(تام|كاف|حسن|أكفى منه|أتم منه|أحسن منه)',
  );
  final likeOnly = RegExp(r'^(?:ومثله|وكذلك|ونظيره) [﴿«][^﴾»]+[﴾»]\s*\.?$');
  void add(int key, String part) {
    var t = tidy(part).replaceAllMapped(
      RegExp(r'\(\(\s*([^)]+?)\s*\)\)'),
      (m) => '«${m[1]}»',
    );
    if (t.isEmpty || key == 0) return;
    if (likeOnly.hasMatch(t) && judgement.isNotEmpty) {
      t = '${t.replaceFirst(RegExp(r'\s*\.$'), '')} [أي: $judgement]';
    }
    for (final m in judgedAs.allMatches(t)) {
      judgement = m[1]!;
    }
    final parts = byAyah[key] ??= [];
    if (parts.isNotEmpty && key == last) {
      parts[parts.length - 1] += ' $t';
    } else {
      parts.add(t);
    }
    last = key;
  }

  for (final (s, text) in paragraphs) {
    if (s != heading) {
      heading = s;
      // A new heading: its surah, after any surah without one.
      if (s + (s >= 63 ? 1 : 0) > current) {
        current = s + (s >= 63 ? 1 : 0);
        at = 0;
        // What it says before its first stop is of the whole surah, or of
        // its opening (الم حيث وقع تام).
        last = current * 1000 + 1;
      }
    }
    // A stop: a quotation followed by its verdict ({لا ريب فيه} كاف).
    // Others explain or give examples, and stay in the text.
    final matches = [
      for (final m in quote.allMatches(text))
        if (verdict.hasMatch(text.substring(m.end)) ||
            likeBefore.hasMatch(text.substring(0, m.start)))
          m,
    ];
    var from = 0;
    var key = last;
    for (final m in matches) {
      final q = (m[1] ?? m[2])!.trim();
      // A judged quotation is looked for further, and into al-Munafiqun,
      // which the book takes on after al-Jumu'a without a heading.
      final judged = m[1] != null && verdict.hasMatch(text.substring(m.end));
      var found = _find(words[current]!, q, at, judged ? 300 : 80);
      var to = current;
      if (found == null && judged && current == 62) {
        to = current + 1;
        found = _find(words[to]!, q, 0, 120);
      }
      if (found == null) continue;
      // The text before this quotation belongs to the stop before it,
      // but for its lead-in (وعلى قوله {…} تام).
      final lead = text.substring(from, m.start);
      final cut = from + (leadIn.firstMatch(lead)?.start ?? lead.length);
      add(key, text.substring(from, cut));
      from = cut;
      current = to;
      at = found.$2;
      key = current * 1000 + found.$1;
    }
    add(key, text.substring(from));
  }

  final texts = <String>[];
  final ayahs = <List<int>>[];
  for (final k in byAyah.keys.toList()..sort()) {
    ayahs.add([k ~/ 1000, k % 1000, texts.length]);
    texts.add(byAyah[k]!.join('\n'));
  }
  final out = File('assets/data/tafsir/$id.json.gz');
  out.writeAsBytesSync(
    gzip.encode(
      utf8.encode(
        jsonEncode({
          'id': id,
          'name': 'المكتفى في الوقف والابتدا',
          'author': 'أبو عمرو الداني',
          'version': 'OpenITI ${args[0].split(RegExp(r'[\\/]')).last}',
          'texts': texts,
          'ayahs': ayahs,
        }),
      ),
    ),
  );
  stdout.writeln(
    '${paragraphs.length} paragraphs, ${ayahs.length} ayahs, '
    '${{for (final a in ayahs) a[0]}.length} surahs, '
    '${(out.lengthSync() / 1024).round()} KB',
  );
}

/// The ayah where [quote] ends, searched in the surah's words from [from]
/// up to [within] words ahead, with the index after it.
(int, int)? _find(
  List<(int, String)> words,
  String quote,
  int from,
  int within,
) {
  final q = [
    for (final w in quote.split(RegExp(r'[\s.،]+')))
      if (skeleton(w).isNotEmpty) skeleton(w),
  ];
  if (q.isEmpty) return null;
  final n = q.length < 3 ? q.length : 3;
  final end = from + within < words.length ? from + within : words.length;
  for (var i = from; i + n <= end; i++) {
    var ok = true;
    for (var k = 0; k < n && ok; k++) {
      ok = words[i + k].$2 == q[k];
    }
    if (!ok) continue;
    // The whole quotation when it is as the text; else its first words.
    var last = i + n - 1;
    var k = n;
    while (k < q.length &&
        last + 1 < words.length &&
        words[last + 1].$2 == q[k]) {
      last++;
      k++;
    }
    return (words[last].$1, last + 1);
  }
  return null;
}
