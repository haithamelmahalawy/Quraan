import 'dart:math' as math;

import 'arabic.dart';
import 'quran_repository.dart';

/// Finds the mushaf page that a photographed page shows, from imperfect OCR
/// text: every recognised word is reduced to its bare letters and pages are
/// scored by the words (and adjacent word pairs) they share with it, rare
/// words weighing more. A page number read in the text adds to its page.
class PageMatcher {
  PageMatcher(QuranRepository quran) {
    for (var p = 1; p <= QuranRepository.pageCount; p++) {
      final words = [
        for (final a in quran.page(p))
          for (final w in a.words) skeleton(w),
      ].where((w) => w.length >= 2).toList();
      for (final w in words.toSet()) {
        _pagesOf.putIfAbsent(w, () => <int>{}).add(p);
      }
      for (var i = 0; i + 1 < words.length; i++) {
        _pairPages.putIfAbsent('${words[i]} ${words[i + 1]}', () => <int>{}).add(p);
      }
    }
  }

  final _pagesOf = <String, Set<int>>{};
  final _pairPages = <String, Set<int>>{};

  double _weight(int pages) => math.log(QuranRepository.pageCount / pages);

  /// The best page for [text], or null when no page clearly stands out.
  ({int page, double score})? match(String text) {
    final tokens = text
        .split(RegExp(r'[\s،؛.,:;!?()«»\[\]{}"' "'" r'\-ـ]+'))
        .map(skeleton)
        .where((w) => w.length >= 2)
        .toList();
    final scores = <int, double>{};
    final pairs = <int, int>{};
    for (final w in tokens.toSet()) {
      final pages = _pagesOf[w];
      if (pages == null || pages.length > 300) continue;
      final weight = _weight(pages.length);
      for (final p in pages) {
        scores[p] = (scores[p] ?? 0) + weight;
      }
    }
    for (var i = 0; i + 1 < tokens.length; i++) {
      final pages = _pairPages['${tokens[i]} ${tokens[i + 1]}'];
      if (pages == null || pages.length > 60) continue;
      final weight = _weight(pages.length) * 1.5;
      for (final p in pages) {
        scores[p] = (scores[p] ?? 0) + weight;
        pairs[p] = (pairs[p] ?? 0) + 1;
      }
    }
    // The printed page number (Arabic-Indic or Western digits).
    for (final m in RegExp(r'[0-9٠-٩]{1,3}').allMatches(text)) {
      final n = int.parse(m[0]!.runes
          .map((c) => c >= 0x0660 && c <= 0x0669 ? c - 0x0660 + 0x30 : c)
          .map(String.fromCharCode)
          .join());
      if (n >= 1 && n <= QuranRepository.pageCount && scores.containsKey(n)) {
        scores[n] = scores[n]! + 6;
      }
    }
    if (scores.isEmpty) return null;
    final ranked = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final best = ranked.first;
    final second = ranked.length > 1 ? ranked[1].value : 0.0;
    // Enough evidence, including runs of consecutive words (which unrelated
    // text does not have), and clearly ahead of the next page.
    if (best.value < 12 || (pairs[best.key] ?? 0) < 2) return null;
    if (best.value < second * 1.3) return null;
    return (page: best.key, score: best.value);
  }
}
