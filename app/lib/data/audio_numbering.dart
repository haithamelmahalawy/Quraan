import 'dart:convert';

import 'package:flutter/services.dart';

typedef VerseWord = ({int ayah, int word});
typedef VerseSpan = ({VerseWord first, VerseWord last});

/// Maps the displayed Kufan verse anchors to the recording's verse boundaries.
/// A verse may share a clip with its neighbour, or span several native clips.
class AudioNumbering {
  AudioNumbering.fromJson(Map<String, dynamic> json)
    : hafsCounts = List<int>.from(json['hafsCounts'] as List),
      wordCounts = [
        for (final counts in json['wordCounts'] as List)
          List<int>.from(counts as List),
      ] {
    final boundaries = json['boundaries'] as Map<String, dynamic>;
    final totals = json['totals'] as Map<String, dynamic>;
    for (final system in totals.keys) {
      final forward = <List<List<int>>>[];
      final reverse = <Map<int, List<int>>>[];
      final endings = <Map<int, VerseWord>>[];
      final wordVerses = <Map<VerseWord, int>>[];
      var total = 0;
      for (var s = 1; s <= hafsCounts.length; s++) {
        final rules = boundaries['$s'] as Map<String, dynamic>? ?? const {};
        final verses = <List<int>>[];
        final clips = <int, List<int>>{};
        final ends = <int, VerseWord>{};
        final markers = <VerseWord, int>{};
        var native = 1;
        for (var h = 1; h <= hafsCounts[s - 1]; h++) {
          final rule = rules['$h'] as Map<String, dynamic>? ?? const {};
          final uncountedBasmala =
              s == 1 &&
              h == 1 &&
              system != 'kufi' &&
              !system.startsWith('makki');
          final numbers = <int>[uncountedBasmala ? 0 : native];
          if (!uncountedBasmala) {
            for (final boundary in rule['internal'] as List? ?? const []) {
              if ((boundary['counted_by'] as List).contains(system)) {
                final at = (ayah: h, word: boundary['wordIndex'] as int);
                ends[native] = at;
                markers[at] = native;
                numbers.add(++native);
              }
            }
            final end = rule['end'];
            if (end == null || (end['counted_by'] as List).contains(system)) {
              final at = (ayah: h, word: wordCounts[s - 1][h - 1] - 1);
              ends[native] = at;
              markers[at] = native;
              native++;
            }
          } else {
            ends[0] = (ayah: 1, word: wordCounts[0][0] - 1);
          }
          verses.add(List.unmodifiable(numbers));
          for (final n in numbers) {
            (clips[n] ??= []).add(h);
          }
        }
        total += native - 1;
        forward.add(verses);
        endings.add(ends);
        wordVerses.add(markers);
        reverse.add({
          for (final e in clips.entries) e.key: List.unmodifiable(e.value),
        });
      }
      if (total != totals[system]) {
        throw FormatException('Invalid verse boundaries for $system: $total');
      }
      _forward[system] = forward;
      _reverse[system] = reverse;
      _ends[system] = endings;
      _markers[system] = wordVerses;
    }
  }

  static Future<AudioNumbering>? _loaded;
  static Future<AudioNumbering> load() => _loaded ??= rootBundle
      .loadString('assets/data/audio_numbering.json')
      .then(
        (s) => AudioNumbering.fromJson(jsonDecode(s) as Map<String, dynamic>),
      );

  final List<int> hafsCounts;
  final List<List<int>> wordCounts;
  final _forward = <String, List<List<List<int>>>>{};
  final _reverse = <String, List<Map<int, List<int>>>>{};
  final _ends = <String, List<Map<int, VerseWord>>>{};
  final _markers = <String, List<Map<VerseWord, int>>>{};

  /// The native verse covering this word, irrespective of displayed numbering.
  int verseAt(String system, int surah, int ayah, int word) {
    final candidates = clips(system, surah, ayah);
    for (final n in candidates) {
      final end = _ends[system]![surah - 1][n]!;
      if (end.ayah > ayah || end.ayah == ayah && end.word >= word) return n;
    }
    throw RangeError('Word outside verse: $surah:$ayah:$word');
  }

  /// Null at a Hafs end that this counting system does not count.
  int? markerAt(String system, int surah, int ayah, int word) =>
      _markers[system]![surah - 1][(ayah: ayah, word: word)];

  VerseSpan span(String system, int surah, int native) {
    final ends = _ends[system]![surah - 1];
    final previous = ends[native - 1];
    final first = previous == null
        ? (ayah: 1, word: 0)
        : previous.word + 1 < wordCounts[surah - 1][previous.ayah - 1]
        ? (ayah: previous.ayah, word: previous.word + 1)
        : (ayah: previous.ayah + 1, word: 0);
    return (first: first, last: ends[native]!);
  }

  /// Audio clips covering a displayed verse's word span in another system.
  List<int> clipsForSpan(String system, int surah, VerseSpan selected) {
    final first = verseAt(
      system,
      surah,
      selected.first.ayah,
      selected.first.word,
    );
    final last = verseAt(system, surah, selected.last.ayah, selected.last.word);
    return [for (var n = first; n <= last; n++) n];
  }

  Iterable<String> get systems => _forward.keys;

  List<int> clips(String system, int surah, int hafsAyah) =>
      _forward[system]![surah - 1][hafsAyah - 1];

  List<int> displayedVerses(String system, int surah, int nativeAyah) =>
      _reverse[system]![surah - 1][nativeAyah]!;

  int nativeCount(String system, int surah) =>
      _reverse[system]![surah - 1].keys.reduce((a, b) => a > b ? a : b);

  /// Current Quranpedia recordings use the qari's associated counting system.
  /// This is a default only; reciter metadata overrides recording differences.
  static String systemFor(String riwaya) => switch (riwaya) {
    'warsh' || 'qalun' => 'madani-last',
    'bazzi' || 'qunbul' => 'makki',
    'duri_abuamr' || 'susi' || 'ruways' || 'rawh' => 'basri',
    'hisham' || 'ibn_dhakwan' => 'dimashqi',
    'ibn_wardan' || 'ibn_jammaz' => 'madani-first',
    _ => 'kufi',
  };

  static String displaySystemFor(String riwaya) =>
      riwaya == 'bazzi' ? 'makki-6220' : systemFor(riwaya);
}
