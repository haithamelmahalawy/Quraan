// Builds the layout of the Shamarly mushaf (the Egyptian print, 522 pages of
// 15 lines): for every page, its lines and the first / last Hafs word on
// each, in the format of assets/data/layout.json.
//
//   flutter test tool/shamarly/build_shamarly_test.dart
//
// Reads assets/data/quran.json and ../tools/source/shamarly (see its README):
// the page and position of every ayah-end marker, and the word each page
// starts with. Pages and ayahs start and end exactly as printed: an ayah ends
// on the line of its marker, a surah header (two lines) and its basmala
// (one) follow the surah before. Within an ayah the words are spread over
// the printed stretch, from where it starts to its marker, by their width:
// a word at the edge of a line may fall on the next one.
//
// Output: assets/data/layout_shamarly.json
//   {"source": ..., "first": 2, "pages": [[line, ...], ...]} (from page 2),
//   lines as in layout.json, and ["s", surah, 2] for a two-line header,
//   ["e"] for an empty line.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const src = '../tools/source/shamarly';

/// The page image's text area: lines 89.3 px apart, the first at y ≈ 45;
/// text from the right edge [right] over [width] px; an ayah-end marker is
/// about [marker] px wide.
const pitch = 89.3, top = 45.0, right = 866.0, width = 870.0, marker = 46.0;

/// The ornate opening pages: the line of each marker, their text lines,
/// and a narrower text area.
const openings = {
  2: (
    lines: {'1:1': 0, '1:2': 1, '1:3': 2, '1:4': 2, '1:5': 3, '1:6': 4, '1:7': 6},
    count: 7,
  ),
  3: (lines: {'2:1': 0, '2:2': 1, '2:3': 3, '2:4': 5}, count: 6),
};
const openingRight = 790.0, openingWidth = 700.0;

typedef Ayah = ({int surah, int ayah, List<String> words});

void main() {
  testWidgets('build the Shamarly layout', (tester) async {
    await tester.runAsync(() async {
      await (FontLoader('Hafs')
            ..addFont(rootBundle.load('assets/fonts/hafs.18.ttf')))
          .load();
    });
    final quran = jsonDecode(File('assets/data/quran.json').readAsStringSync())
        as Map<String, dynamic>;
    final ayahs = <Ayah>[
      for (final a in quran['ayahs'] as List)
        (surah: a[0] as int, ayah: a[1] as int, words: (a[4] as String).split(' ')),
    ];
    final indexOf = {
      for (final (i, a) in ayahs.indexed) '${a.surah}:${a.ayah}': i,
    };
    final surahAyahs = [for (final s in quran['surahs'] as List) s['ayahs'] as int];

    // Marker of each ayah: page, line, x.
    final markers = <int, ({int page, int line, double x})>{};
    for (final m in jsonDecode(File('$src/markers.json').readAsStringSync())
        as List) {
      final (page, surah, ayah, x, y) =
          (m[0] as int, m[1] as int, m[2] as int, (m[3] as num).toDouble(), (m[4] as num).toDouble());
      if (ayah == 0) continue;
      final key = '$surah:$ayah';
      final line = openings[page]?.lines[key] ??
          ((y - top) / pitch).round().clamp(0, 14);
      markers[indexOf[key]!] = (page: page, line: line, x: x);
    }
    final firstWord = {
      for (final l in File('$src/first_word.txt').readAsLinesSync().skip(1))
        if (l.contains(','))
          int.parse(l.split(',')[0]): int.parse(l.split(',')[1]),
    };

    // Where each page starts: the ayah after the last one ending before it,
    // from the word the index gives.
    const first = 2, last = 522;
    final starts = <int, (int, int)>{first: (0, 0)};
    var ended = -1;
    for (var p = first + 1; p <= last; p++) {
      for (final MapEntry(key: i, value: m) in markers.entries) {
        if (m.page == p - 1) ended = math.max(ended, i);
      }
      final w = firstWord[p] ?? 0;
      final next = ended + 1;
      if (w >= ayahs[next].words.length || markers[next]!.page < p) {
        fail('page $p: starts at word $w of ${ayahs[next].surah}:${ayahs[next].ayah}');
      }
      starts[p] = (next, w);
    }

    // Surah headers (two lines) and basmalas (one), after the surah before.
    final header = <int, Map<int, String>>{}; // page -> line -> 'h' / 'b'
    void put(int page, int line, String kind) =>
        (header[page] ??= {})[line] = kind;
    for (var s = 3; s <= 114; s++) {
      final end = markers[indexOf['${s - 1}:${surahAyahs[s - 2]}']!]!;
      final slots = [ 'h', 'h', if (s != 9) 'b'];
      final free = 14 - end.line;
      var (page, line) = (end.page, end.line + 1);
      if (free < 2) (page, line) = (end.page + 1, 0); // a header is not split
      for (final kind in slots) {
        if (line > 14) (page, line) = (page + 1, 0);
        put(page, line++, kind);
      }
    }

    // Word widths in the Hafs font.
    double measure(String word) {
      final painter = TextPainter(
        text: TextSpan(text: word, style: const TextStyle(fontFamily: 'Hafs', fontSize: 20)),
        textDirection: TextDirection.rtl,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w + 5; // and the space after it
    }

    final pages = <List<Object>>[];
    var estimated = 0, total = 0;
    for (var p = first; p <= last; p++) {
      final opening = openings[p];
      final (r, w) = opening == null ? (right, width) : (openingRight, openingWidth);
      final slots = opening == null
          ? [for (var l = 0; l < 15; l++) if (header[p]?[l] == null) l]
          : [for (var l = 0; l < opening.count; l++) l];
      double at(int line, double x) => slots.indexOf(line) * w + (r - x);

      // The page's words, ayah by ayah, each on a text slot.
      final lineOf = <(int, int), int>{};
      final (startAyah, startWord) = starts[p]!;
      final (endAyah, endWord) = p == last ? (ayahs.length, 0) : starts[p + 1]!;
      for (var i = startAyah; i <= endAyah && i < ayahs.length; i++) {
        final from = i == startAyah ? startWord : 0;
        final to = i == endAyah ? endWord : ayahs[i].words.length;
        if (from >= to) continue;
        // Where the run starts: after the marker before it on this page, or
        // at the start of a line (a page, or a surah after its header).
        final before = markers[i - 1];
        final double begin;
        if (from > 0 || i == startAyah && from == 0 && before?.page != p) {
          begin = 0;
        } else if (ayahs[i].ayah == 1) {
          // After its header: the first line below it.
          final prev = before!.page == p ? slots.indexOf(before.line) + 1 : 0;
          begin = prev * w;
        } else {
          begin = at(before!.line, before.x) + marker / 2;
        }
        final m = markers[i]!;
        final end = m.page == p ? at(m.line, m.x) - marker / 2 : slots.length * w;
        final widths = [for (var k = from; k < to; k++) measure(ayahs[i].words[k])];
        final sum = widths.fold(0.0, (a, b) => a + b);
        var acc = 0.0;
        final lastSlot = m.page == p ? slots.indexOf(m.line) : slots.length - 1;
        var floor = (begin / w).floor().clamp(0, slots.length - 1);
        for (var k = from; k < to; k++) {
          final c = begin + (acc + widths[k - from] / 2) / sum * (end - begin);
          acc += widths[k - from];
          var slot = (c / w).floor().clamp(floor, lastSlot);
          if (k == to - 1) slot = lastSlot; // the word before the marker
          floor = slot;
          lineOf[(i, k)] = slots[slot];
          total++;
          if (m.page != p || slot != lastSlot) estimated++;
        }
      }

      // The page's lines.
      final out = <Object>[if (opening != null) 'c'];
      final lineCount = opening == null ? 15 : opening.count;
      if (p == 2) out.add(['s', 1]);
      if (p == 3) out.addAll([['s', 2], ['b', 2]]);
      for (var l = 0; l < lineCount; l++) {
        final kind = opening == null ? (header[p]?[l]) : null;
        if (kind == 'h') {
          if (header[p]?[l - 1] == 'h') continue; // its second line
          final surah = ayahs[_firstAyahAfter(header, p, l, starts, ayahs, markers)].surah;
          out.add(['s', surah, header[p]?[l + 1] == 'h' ? 2 : 1]);
          continue;
        }
        if (kind == 'b') {
          final surah = ayahs[_firstAyahAfter(header, p, l, starts, ayahs, markers)].surah;
          out.add(['b', surah]);
          continue;
        }
        final words = [
          for (final MapEntry(:key, :value) in lineOf.entries)
            if (value == l) key,
        ]..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
        if (words.isEmpty) {
          out.add(['e']);
        } else {
          final (a, b) = (words.first, words.last);
          out.add(['a', ayahs[a.$1].surah, ayahs[a.$1].ayah, a.$2,
              ayahs[b.$1].surah, ayahs[b.$1].ayah, b.$2]);
        }
      }
      pages.add(out);
    }
    File('assets/data/layout_shamarly.json').writeAsStringSync(jsonEncode({
      'source': 'Shamarly mushaf (Egyptian print): ayah-end markers from '
          'github.com/Mr-DDDAlKilanny/Shamarly, page starts from '
          'github.com/quran/quran_android/issues/1180',
      'first': first,
      'pages': pages,
    }));
    // ignore: avoid_print
    print('${pages.length} pages, $total words, $estimated placed by width');
  });
}

/// The ayah whose surah a header or basmala on [page], [line] belongs to:
/// the first ayah starting after it.
int _firstAyahAfter(
  Map<int, Map<int, String>> header,
  int page,
  int line,
  Map<int, (int, int)> starts,
  List<Ayah> ayahs,
  Map<int, ({int page, int line, double x})> markers,
) {
  // The last ayah ending before this point, then the next one.
  var best = -1;
  for (final MapEntry(key: i, value: m) in markers.entries) {
    if (m.page < page || m.page == page && m.line < line) {
      best = math.max(best, i);
    }
  }
  return best + 1;
}
