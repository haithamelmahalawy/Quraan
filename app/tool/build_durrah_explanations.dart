// The Durrah's sharh: «شرح الزبيدي على الدرة المضية», from the typed copy of
// the Encyclopaedia of the Quran (quranpedia.net/ar/book/19426, the file
// archive.org/download/Quran12000/Quraan12625.zip).
//
//   pdftotext -enc UTF-8 <the book's pdf> <book.txt>
//   dart run tool/build_durrah_explanations.dart <book.txt>
//
// Its font turned some letters into others when it was printed to pdf: a lam
// joined on its right a mim (عمى for على), the ha a ya, a waw or an alif maqsura
// by its place (ىذا، اليمز، كتابو), a ra or a zay before an alif after it (ق أر
// for قرأ). The letters are put back by those rules, and where a word could be
// read two ways, as the words of the app's other books are written (Abu Shama,
// Kharouf, the tafsirs). Each explanation is told with the bayts it follows.
import 'dart:convert';
import 'dart:io';

const _joining = 'بتثجحخسشصضطظعغفقكلمنهيئةـ';
const _source =
    'شرح الزبيدي على الدرة المضية في القراءات الثلاث، النسخة المكتوبة في '
    'الموسوعة القرآنية quranpedia.net';
const _url = 'https://quranpedia.net/ar/book/19426';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'usage: dart run tool/build_durrah_explanations.dart <book.txt>',
    );
    exit(64);
  }
  final vocab = _vocabulary();
  stdout.writeln('vocabulary: ${vocab.words.length} words');
  final raw = File(args[0]).readAsStringSync();
  final pages = _pages(raw);
  final fixed = [for (final p in pages) _fixText(p, vocab)];
  final poems =
      jsonDecode(File('assets/data/manzumat.json').readAsStringSync()) as Map;
  final durrah = [
    for (final v in poems['durrah'] as List)
      (n: v[0] as int, text: '${v[2]} ${v[3]}'),
  ];
  final explained = _explain(fixed, durrah);
  final file = File('assets/data/poem_explanations.json');
  final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  data['durrahSource'] = _source;
  data['durrahUrl'] = _url;
  data['durrah'] = explained;
  file.writeAsStringSync(jsonEncode(data));
  final told = {for (final e in explained) ...(e[4] as List).cast<int>()};
  stdout.writeln(
    'durrah: ${explained.length} explanations, ${told.length} of '
    '${durrah.length} bayts told',
  );
}

/// The book's pages: the text between its page numbers.
List<String> _pages(String raw) {
  final text = raw.replaceAll(RegExp('[\u202A-\u202E‎‏]'), '');
  final pages = <String>[];
  final page = StringBuffer();
  for (final line in text.split('\n')) {
    final l = line.trim();
    if (RegExp(r'^\d+$').hasMatch(l) || l.contains('\f')) {
      pages.add(page.toString());
      page.clear();
      final rest = l.replaceAll(RegExp(r'[\f\d]'), '').trim();
      if (rest.isNotEmpty) page.writeln(rest);
      continue;
    }
    if (l.isNotEmpty) page.writeln(l);
  }
  if (page.isNotEmpty) pages.add(page.toString());
  return pages;
}

class _Vocab {
  _Vocab(this.words, this.grams);
  final Map<String, int> words;
  final Map<String, int> grams;

  int count(String w) => words[w] ?? 0;

  /// How Arabic the word looks, letter by letter, where no book has it.
  double likelihood(String w) {
    final s = '^$w\$';
    var score = 0.0;
    for (var i = 0; i + 3 <= s.length; i++) {
      score += (grams[s.substring(i, i + 3)] ?? 0) > 0 ? 1 : -2;
    }
    return score;
  }
}

String _bare(String s) =>
    s.replaceAll(RegExp('[ً-ٰٟۖ-ۭ]'), '').replaceAll('ـ', '');

_Vocab _vocabulary() {
  final words = <String, int>{};
  final grams = <String, int>{};
  void add(String text) {
    for (final m in RegExp('[ء-ي]+').allMatches(_bare(text))) {
      final w = m[0]!;
      words[w] = (words[w] ?? 0) + 1;
      final s = '^$w\$';
      for (var i = 0; i + 3 <= s.length; i++) {
        final g = s.substring(i, i + 3);
        grams[g] = (grams[g] ?? 0) + 1;
      }
    }
  }

  void walk(Object? j) {
    if (j is String) {
      add(j);
    } else if (j is List) {
      j.forEach(walk);
    } else if (j is Map) {
      j.values.forEach(walk);
    }
  }

  final explanations = jsonDecode(
    File('assets/data/poem_explanations.json').readAsStringSync(),
  ) as Map;
  walk(explanations['shatibiyya']);
  walk(jsonDecode(File('assets/data/kharouf.json').readAsStringSync()));
  walk(jsonDecode(File('assets/data/manzumat.json').readAsStringSync()));
  for (final f in Directory(
    'assets/data/tafsir',
  ).listSync().whereType<File>()) {
    if (!f.path.endsWith('.json.gz')) continue;
    walk(jsonDecode(utf8.decode(gzip.decode(f.readAsBytesSync()))));
  }
  return _Vocab(words, grams);
}

/// The page's text with its letters put back.
String _fixText(String text, _Vocab vocab) {
  const word = '[ء-ٰٟ]';
  // A ra or zay before an alif, swapped with it and parted from the letter it
  // joined: «ق أر» for «قرأ»، «الك ارم» for «الكرام»، «كثي ار» for «كثيرا».
  final t = text.replaceAllMapped(
    RegExp('($word*[$_joining][ً-ٟ]*) ([اأإآ])([رز])($word*)'),
    (m) {
      final joinedText = '${m[1]}${m[3]}${m[2]}${m[4]}';
      final joined = vocab.count(_bare(_fixWord(joinedText, vocab)));
      final left = vocab.count(_bare(_fixWord(m[1]!, vocab)));
      final right = vocab.count(
        _bare(_fixWord('${m[2]}${m[3]}${m[4]}', vocab)),
      );
      // One letter alone is no word: «ق أر»، «ي ازد».
      final short = _bare(m[1]!).length == 1;
      // Two letters alone («وق أر») neither: «وقرأ».
      final two = _bare(m[1]!).length == 2 && joined >= right;
      return left == 0 || joined > 0 && (short || two || right == 0)
          ? joinedText
          : m[0]!;
    },
  );
  return t.replaceAllMapped(RegExp('$word+'), (m) => _fixWord(m[0]!, vocab));
}

final _cache = <String, String>{};

/// The letters' choices of [w] (its marks kept): a mim joined on its right may
/// be a lam, a ya inside a ha, a waw at its end a ha.
List<List<String>> _options(String w) {
  final options = <List<String>>[];
  String? before;
  final letters = [
    for (var i = 0; i < w.length; i++)
      if (!RegExp('[ً-ٰٟ]').hasMatch(w[i])) i,
  ];
  for (var i = 0; i < w.length; i++) {
    final c = w[i];
    if (!letters.contains(i)) {
      options.add([c]);
      continue;
    }
    final at = letters.indexOf(i);
    final next = at + 1 < letters.length ? w[letters[at + 1]] : null;
    final joinedBefore = before != null && _joining.contains(before);
    if (c == 'م' && joinedBefore && next != 'ا') {
      options.add(['م', 'ل']);
    } else if (c == 'ي' && joinedBefore && next != null) {
      options.add(['ي', 'ه']);
    } else if (c == 'و' && joinedBefore && next == null) {
      options.add(['و', 'ه']);
    } else {
      options.add([c]);
    }
    before = c;
  }
  return options;
}

/// A word with its letters put back: the reading a book has, the likeliest
/// where none has it.
String _fixWord(String w, _Vocab vocab) => _cache[w] ??= () {
  // The ha at the start of its letters joined: an alif maqsura, never one.
  final base = w.replaceAllMapped(RegExp('ى(?=[ً-ٟ]*[ء-ي])'), (_) => 'ه');
  final starts = <String>[base];
  // At the word's start: «ازلت» for «زالت»، «اروياه» for «راوياه».
  final swap = RegExp('^([وفبلك]?[ً-ٟ]*)([اأ])([ً-ٟ]*)([رز])').firstMatch(base);
  if (swap != null) {
    starts.add(
      base.replaceRange(
        swap.start,
        swap.end,
        '${swap[1]}${swap[4]}${swap[2]}${swap[3]}',
      ),
    );
  }
  var best = base;
  var bestCount = vocab.count(_bare(base)) * 5;
  var bestLike = vocab.likelihood(_bare(base));
  for (final start in starts) {
    final opts = _options(start);
    final ambiguous = [
      for (var i = 0; i < opts.length; i++)
        if (opts[i].length > 1) i,
    ];
    if (ambiguous.length > 12) continue;
    for (var mask = 0; mask < 1 << ambiguous.length; mask++) {
      final letters = [for (final o in opts) o.first];
      for (var b = 0; b < ambiguous.length; b++) {
        if (mask & (1 << b) != 0) letters[ambiguous[b]] = opts[ambiguous[b]][1];
      }
      final c = letters.join();
      // As printed, unless the other reading is far commoner (يضم, not يضل).
      final n = vocab.count(_bare(c)) * (c == start ? 5 : 1);
      final like = vocab.likelihood(_bare(c));
      if (n > bestCount || n == bestCount && n == 0 && like > bestLike) {
        best = c;
        bestCount = n;
        bestLike = like;
      }
    }
  }
  return best;
}();

/// The explanations, each after the bayts it follows: [n, text, url, page,
/// group, source], as the Shatibiyya's.
List<List<Object>> _explain(
  List<String> pages,
  List<({int n, String text})> durrah,
) {
  // The lines quoting bayts: «( ... ... )», after a chapter's name at most,
  // the readers' letters in brackets of their own; a bayt may run on to the
  // next line, till its brackets close.
  final parts = <({String text, int page, bool bayt})>[];
  for (var p = 0; p < pages.length; p++) {
    final lines = pages[p].split('\n');
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      final open = line.indexOf('(');
      if (!line.contains('...') || open < 0 || open > 40) {
        parts.add((text: line, page: p + 1, bayt: false));
        continue;
      }
      int depth(String s) =>
          '('.allMatches(s).length - ')'.allMatches(s).length;
      while (depth(line) > 0 &&
          i + 1 < lines.length &&
          !lines[i + 1].trimLeft().startsWith('أي')) {
        line = '$line ${lines[++i]}';
      }
      if (open > 0) {
        parts.add((text: line.substring(0, open), page: p + 1, bayt: false));
      }
      parts.add((text: line.substring(open), page: p + 1, bayt: true));
    }
  }
  String letters(String s) =>
      _bare(s)
          .replaceAllMapped(RegExp(r'\(\s*(\S)\s*\)\s*'), (m) => m[1]!)
          .replaceAll(RegExp('[أإآٱ]'), 'ا')
          .replaceAll('ى', 'ي')
          .replaceAll('ة', 'ه')
          .replaceAll(RegExp('[^\u0621-\u064A]'), '');
  Set<String> grams(String s) => {
    for (var i = 0; i + 3 <= s.length; i++) s.substring(i, i + 3),
  };
  final corpus = [for (final b in durrah) letters(b.text)];
  var next = 0;
  double dice(Set<String> a, Set<String> b) =>
      2 * a.where(b.contains).length / (a.length + b.length);

  /// The bayts a line quotes: one, or two together, near the last found.
  List<int> match(String text) {
    final g = grams(letters(text));
    if (g.length < 10) return const [];
    var best = <int>[];
    var score = .4;
    for (var i = next; i < corpus.length && i < next + 25; i++) {
      for (final span in [1, 2, 3]) {
        if (i + span > corpus.length) continue;
        final s = dice(g, grams(corpus.sublist(i, i + span).join()));
        if (s > score) {
          best = [for (var k = i; k < i + span; k++) k];
          score = s;
        }
      }
    }
    if (best.isEmpty) return const [];
    next = best.last + 1;
    return [for (final k in best) durrah[k].n];
  }

  final out = <List<Object>>[];
  var group = <int>[];
  var page = 1;
  final body = StringBuffer();
  void flush() {
    final text = body
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAllMapped(RegExp(r'\s+([.,،؛:؟)])'), (m) => m[1]!)
        .replaceAll(RegExp(r'\(\s+'), '(')
        .trim();
    if (group.isNotEmpty && text.length > 20) {
      out.add([
        group.first,
        text,
        _url,
        'ص $page',
        [...group],
        _source,
      ]);
    }
    group = [];
    body.clear();
  }

  for (var i = 0; i < parts.length; i++) {
    final part = parts[i];
    if (part.bayt) {
      final ns = match(part.text);
      if (ns.isEmpty) {
        body.write(' ${part.text} ');
        continue;
      }
      // A bayt after an explanation starts the next; after a bayt, joins it.
      if (body.toString().trim().length > 20) flush();
      if (group.isEmpty) page = part.page;
      body.clear();
      group.addAll(ns);
    } else {
      var text = part.text;
      // The chapter's name just before the next bayt is not of this sharh.
      final nextIsBayt = i + 1 < parts.length && parts[i + 1].bayt;
      if (nextIsBayt && text.length < 60 && !text.contains('.')) text = '';
      body.write(' $text ');
    }
  }
  flush();
  return out;
}
