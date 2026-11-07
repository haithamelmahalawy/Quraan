import 'dart:math' as math;

import 'arabic.dart';
import 'quran_repository.dart';

/// Finds the mushaf page that a photographed page shows, from imperfect OCR
/// text: every recognised word is reduced to its bare letters and pages are
/// scored by the words (and adjacent word pairs) they share with it, rare
/// words weighing more. A page number read in the text adds to its page.
///
/// OCR of Uthmani script often runs words together or splits them, so each
/// line is also compared as a run of letters, spaces ignored: pages score
/// for every run of [_gram] letters they share with it.
class PageMatcher {
  PageMatcher(QuranRepository quran)
    : _first = quran.firstPage,
      _last = quran.lastPage {
    for (var p = _first; p <= _last; p++) {
      final words = [
        for (final a in quran.page(p))
          for (final w in a.words) skeleton(w),
      ].where((w) => w.length >= 2).toList();
      for (final w in words.toSet()) {
        _pagesOf.putIfAbsent(w, () => <int>{}).add(p);
      }
      for (var i = 0; i + 1 < words.length; i++) {
        _pairPages
            .putIfAbsent('${words[i]} ${words[i + 1]}', () => <int>{})
            .add(p);
      }
      for (final g in _grams(words.join()).toSet()) {
        (_gramPages[g] ??= <int>[]).add(p);
      }
    }
  }

  final _pagesOf = <String, Set<int>>{};
  final _pairPages = <String, Set<int>>{};
  final _gramPages = <int, List<int>>{};

  static const _gram = 5;

  /// Runs of [_gram] letters of [letters], each packed into an int (six bits
  /// a letter).
  static Iterable<int> _grams(String letters) sync* {
    final codes = letters.codeUnits;
    for (var i = 0; i + _gram <= codes.length; i++) {
      var g = 0;
      for (var k = i; k < i + _gram; k++) {
        g = g << 6 | (codes[k] - 0x0620);
      }
      yield g;
    }
  }

  final int _first, _last;

  double _weight(int pages) => math.log((_last - _first + 1) / pages);

  /// The page whose printed number [text] reads (Arabic-Indic or Western
  /// digits), or null: one number, within the mushaf's pages.
  int? pageNumber(String text) {
    final numbers = {
      for (final m in RegExp(r'[0-9٠-٩]{1,3}').allMatches(text)) _number(m[0]!),
    }.where((n) => n >= _first && n <= _last);
    return numbers.length == 1 ? numbers.single : null;
  }

  static int _number(String digits) => int.parse(
    digits.runes
        .map((c) => c >= 0x0660 && c <= 0x0669 ? c - 0x0660 + 0x30 : c)
        .map(String.fromCharCode)
        .join(),
  );

  /// The best page for [text], or null when no page clearly stands out.
  /// The runs of its text must be on [lines] lines at least: two for a band
  /// of the page; one for a single line, which must then stand further
  /// ahead of the next page.
  ({int page, double score})? match(String text, {int lines = 2}) =>
      _match(text, lines);

  /// The pages whose number has [digits] in it, in their order, though not
  /// side by side: what a number read with some of its digits lost may be
  /// (٢ of ٢٠٦: 2, 12, 20…29, 102, 200…299…).
  Set<int> pagesWithDigits(String digits) {
    final read = [
      for (final c in digits.runes)
        if (c >= 0x30 && c <= 0x39)
          c - 0x30
        else if (c >= 0x0660 && c <= 0x0669)
          c - 0x0660,
    ];
    if (read.isEmpty) return {};
    bool within(int page) {
      var i = 0;
      for (final c in '$page'.codeUnits) {
        if (i < read.length && c - 0x30 == read[i]) i++;
      }
      return i == read.length;
    }

    return {
      for (var p = _first; p <= _last; p++)
        if (within(p)) p,
    };
  }

  /// The page among [pages] that [text] shows, or null: one line of it is
  /// enough, the number read having already narrowed them down.
  ({int page, double score})? matchAmong(String text, Set<int> pages) =>
      pages.isEmpty ? null : _match(text, 1, among: pages);

  ({int page, double score})? _match(
    String text,
    int onLines, {
    Set<int>? among,
  }) {
    final raw = text.split('\n');
    final lines = [
      for (final line in raw)
        line
            .split(
              RegExp(
                r'[\s،؛.,:;!?()«»\[\]{}"'
                "'"
                r'\-ـ]+',
              ),
            )
            .map(skeleton)
            .where((w) => w.length >= 2)
            .toList(),
    ];
    final scores = <int, double>{};
    // The lines with runs of the page's text: consecutive words or letters,
    // which unrelated text has at most by chance, and on few lines.
    final runLines = <int, Set<int>>{};
    void run(int page, int line, double weight) {
      scores[page] = (scores[page] ?? 0) + weight;
      (runLines[page] ??= <int>{}).add(line);
    }

    for (final w in lines.expand((l) => l).toSet()) {
      final pages = _pagesOf[w];
      if (pages == null || pages.length > 300) continue;
      final weight = _weight(pages.length);
      for (final p in pages) {
        scores[p] = (scores[p] ?? 0) + weight;
      }
    }
    for (final (l, tokens) in lines.indexed) {
      for (var i = 0; i + 1 < tokens.length; i++) {
        final pages = _pairPages['${tokens[i]} ${tokens[i + 1]}'];
        if (pages == null || pages.length > 60) continue;
        final weight = _weight(pages.length) * 1.5;
        for (final p in pages) {
          run(p, l, weight);
        }
      }
    }
    // Runs of letters along each line, whatever the spaces. A run counts
    // for a page only when the next or previous one does too (a longer
    // stretch of the page's text), since short runs also occur by chance.
    final counted = <(int, int)>{};
    for (final (l, line) in raw.indexed) {
      final grams = _grams(skeleton(line)).toList();
      List<int>? pagesAt(int i) =>
          i < 0 || i >= grams.length ? null : _gramPages[grams[i]];
      for (var i = 0; i < grams.length; i++) {
        final pages = pagesAt(i);
        if (pages == null || pages.length > 30) continue;
        final weight = _weight(pages.length) * 0.4;
        for (final p in pages) {
          if (!(pagesAt(i - 1)?.contains(p) ?? false) &&
              !(pagesAt(i + 1)?.contains(p) ?? false)) {
            continue;
          }
          if (counted.add((grams[i], p))) run(p, l, weight);
        }
      }
    }
    // The printed page number (Arabic-Indic or Western digits), counted once
    // however often OCR noise repeats it.
    final numbers = {
      for (final m in RegExp(r'[0-9٠-٩]{1,3}').allMatches(text)) _number(m[0]!),
    };
    for (final n in numbers) {
      if (n >= _first && n <= _last && scores.containsKey(n)) {
        scores[n] = scores[n]! + 6;
      }
    }
    if (among != null) scores.removeWhere((p, _) => !among.contains(p));
    if (scores.isEmpty) return null;
    final ranked = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final best = ranked.first;
    final second = ranked.length > 1 ? ranked[1].value : 0.0;
    // Enough evidence (photographed pages read as noise score up to ~20),
    // runs of the page's text on at least two lines (a phrase quoted in
    // other text has one), and clearly ahead of the next page.
    if (best.value < (among == null ? 22 : 10) ||
        (runLines[best.key]?.length ?? 0) < onLines) {
      return null;
    }
    if (best.value < second * (onLines < 2 ? 1.6 : 1.3)) return null;
    return (page: best.key, score: best.value);
  }
}
