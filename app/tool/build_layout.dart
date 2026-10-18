// Builds the Madinah mushaf line layout: for every page, its 15 lines and the
// first / last Hafs word on each, so pages break exactly as in the print.
//
//   dart run tool/build_layout.dart [layoutDir]
//
// Reads assets/data/quran.json (from build_data.dart) and the quran.com
// verses-by-chapter dumps in layoutDir (default ../tools/source/layout,
// s1.json ... s114.json with word_fields=line_v2,v2_page,text_uthmani).
//
// Output: assets/data/layout.json and assets/data/qcf_v2.json
//
// qcf_v2.json gives, for every ayah (in quran.json order), the glyphs of
// the KFGQPC QCF V2 page font for each Hafs word and the ayah-end ornament:
//   {"ayahs": [[["glyphs", ...], "end"], ...]}
// The page fonts (p1.ttf .. p604.ttf) draw the words as printed.
//
// layout.json:
//   {"source": ..., "pages": [[line, ...], ...]} where a line is
//   ["s", surah]                       surah name
//   ["b", surah]                       basmala
//   ["a", s1, a1, w1, s2, a2, w2]      Hafs words (s1:a1:w1) .. (s2:a2:w2)
//   and pages 1-2 carry a leading "c" (centered lines).
import 'dart:convert';
import 'dart:io';

typedef WordRef = (int surah, int ayah, int word);

void main(List<String> args) {
  final dir = args.isNotEmpty ? args[0] : '../tools/source/layout';
  final quran = jsonDecode(File('assets/data/quran.json').readAsStringSync())
      as Map<String, dynamic>;

  // Hafs words per ayah, and the page of each ayah.
  final words = <String, List<String>>{};
  final pageOf = <String, int>{};
  final ayahOrder = <String>[];
  for (final a in quran['ayahs'] as List) {
    final key = '${a[0]}:${a[1]}';
    words[key] = (a[4] as String).split(' ');
    pageOf[key] = a[2] as int;
    ayahOrder.add(key);
  }

  // (page, line) of every Hafs word, and its QCF V2 glyphs.
  final place = <WordRef, (int, int)>{};
  final glyphs = <String, (List<String>, String)>{};
  for (var s = 1; s <= 114; s++) {
    final json = jsonDecode(File('$dir/s$s.json').readAsStringSync());
    for (final v in json['verses'] as List) {
      final key = v['verse_key'] as String;
      final a = int.parse(key.split(':')[1]);
      final api = (v['words'] as List)
          .where((w) => w['char_type_name'] == 'word')
          .toList();
      final ours = words[key]!;
      final lineOf = _mapWords(
        ours,
        [for (final w in api) w['text_uthmani'] as String],
      );
      // Each of our words shows the glyphs of the quran.com words it covers
      // (the two texts split a few ayahs differently).
      final end = (v['words'] as List)
          .firstWhere((w) => w['char_type_name'] == 'end')['code_v2'] as String;
      glyphs[key] = (
        [
          for (var i = 0; i < ours.length; i++)
            [
              for (var k = lineOf[i];
                  k < (i + 1 < ours.length ? lineOf[i + 1] : api.length);
                  k++)
                api[k]['code_v2'] as String,
            ].join(' '),
        ],
        end,
      );
      for (var i = 0; i < ours.length; i++) {
        final w = api[lineOf[i]];
        place[(s, a, i)] = (w['v2_page'] as int, w['line_v2'] as int);
        if (w['v2_page'] != pageOf[key]) {
          throw StateError('$key word $i: page ${w['v2_page']} '
              'but KFGQPC page ${pageOf[key]}');
        }
      }
    }
  }

  // Words grouped by page and line, in reading order.
  final lines = List.generate(605, (_) => <int, List<WordRef>>{});
  for (final key in ayahOrder) {
    final [s, a] = key.split(':').map(int.parse).toList();
    for (var i = 0; i < words[key]!.length; i++) {
      final (p, l) = place[(s, a, i)]!;
      lines[p].putIfAbsent(l, () => []).add((s, a, i));
    }
  }

  final pages = <List<Object>>[];
  var headerPending = 0; // surah whose name closed the previous page
  for (var p = 1; p <= 604; p++) {
    final used = lines[p];
    final count = p <= 2 ? used.keys.reduce((a, b) => a > b ? a : b) : 15;
    final out = <Object>[if (p <= 2) 'c'];
    var l = 1;
    while (l <= count) {
      final ws = used[l];
      if (ws != null) {
        final (s1, a1, w1) = ws.first;
        final (s2, a2, w2) = ws.last;
        out.add(['a', s1, a1, w1, s2, a2, w2]);
        l++;
        continue;
      }
      // A run of lines without words: surah name and/or basmala of the
      // surah that starts after them (on this page or the next).
      var end = l;
      while (end <= count && used[end] == null) {
        end++;
      }
      final run = end - l;
      final next = end <= count ? used[end]!.first.$1 : _firstSurahOf(lines[p + 1]);
      final withBasmala = next != 1 && next != 9;
      if (headerPending == next) {
        if (run != 1 || !withBasmala) throw StateError('page $p line $l');
        out.add(['b', next]);
      } else if (run == 2 && withBasmala) {
        out..add(['s', next])..add(['b', next]);
      } else if (run == 1) {
        out.add(['s', next]);
        if (end > count && withBasmala) headerPending = next;
      } else {
        throw StateError('page $p: $run empty lines before surah $next');
      }
      l = end;
    }
    if (out.whereType<List>().length != count) {
      throw StateError('page $p has ${out.length} lines');
    }
    pages.add(out);
  }

  File('assets/data/layout.json').writeAsStringSync(jsonEncode({
    'source': 'Madinah mushaf, KFGQPC V2 (1421H) line layout via quran.com',
    'pages': pages,
  }));
  File('assets/data/qcf_v2.json').writeAsStringSync(jsonEncode({
    'source': 'KFGQPC QCF V2 glyph codes via quran.com (code_v2)',
    'ayahs': [
      for (final key in ayahOrder) [glyphs[key]!.$1, glyphs[key]!.$2],
    ],
  }));
  final headers =
      pages.expand((p) => p).whereType<List>().where((l) => l[0] != 'a').length;
  stdout.writeln('layout.json: ${pages.length} pages, $headers header lines');
}

int _firstSurahOf(Map<int, List<WordRef>> page) {
  final first = page.keys.reduce((a, b) => a < b ? a : b);
  return page[first]!.first.$1;
}

/// For each of [ours], the index in [theirs] of the word it starts in. The
/// two texts split a few ayahs differently (e.g. يَبۡنَؤُمَّ), so words are
/// matched on their letter offsets.
List<int> _mapWords(List<String> ours, List<String> theirs) {
  if (ours.length == theirs.length) {
    return List.generate(ours.length, (i) => i);
  }
  List<int> starts(List<String> ws) {
    final out = <int>[];
    var n = 0;
    for (final w in ws) {
      out.add(n);
      n += _letters(w);
    }
    return out;
  }

  final a = starts(ours), b = starts(theirs);
  return [
    for (final offset in a)
      b.lastIndexWhere((start) => start <= offset).clamp(0, theirs.length - 1),
  ];
}

int _letters(String w) =>
    w.runes.where((c) => (c >= 0x0621 && c <= 0x064A) || c == 0x0671).length;
