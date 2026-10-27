/// The i'rab of one ayah, word by word, from a book that quotes each word
/// and gives its i'rab after it («ذلِكَ» ذا اسم إشارة …), as al-Da'as's
/// does. Its text runs over several ayahs together, headed by their numbers
/// ([سورة البقرة (٢) : الآيات ١ الى ٥]), and an ayah's entry may begin with
/// the end of the one before: the quoted words are matched in order with
/// the Hafs words of the ayahs, and only [target]'s kept.
///
/// [texts] are the book's entries of the ayahs around, in order; [ayahs]
/// the ayah numbers with their Hafs words, from early enough to cover the
/// first entry. Empty when nothing quoted is found of [target].
List<({String word, String e3rab})> e3rabWords(
  List<String> texts,
  List<(int, List<String>)> ayahs,
  int target,
) {
  final stream = [
    for (final (ayah, words) in ayahs)
      for (final w in words)
        if (_skeleton(w).isNotEmpty) (ayah: ayah, word: _skeleton(w)),
  ];
  final lines = <({String word, String e3rab, int ayah})>[];
  int? at;
  for (final (t, text) in texts.indexed) {
    final heads = _heading.allMatches(text).toList();
    // The pieces of the text: before the first heading, the end of the
    // ayahs before (not matched in the first entry); then each heading's.
    final pieces = <(int, int, int?)>[
      if (t > 0)
        (0, heads.isEmpty ? text.length : _headStart(text, heads.first), null),
      for (final (i, h) in heads.indexed)
        (
          h.end,
          i + 1 < heads.length ? _headStart(text, heads[i + 1]) : text.length,
          _number(h[1]!),
        ),
    ];
    for (final (start, end, ayah) in pieces) {
      if (end <= start) continue;
      if (ayah != null) {
        final first = stream.indexWhere((w) => w.ayah >= ayah);
        at = first < 0 ? null : first;
      }
      if (at == null) continue;
      for (final m in RegExp(
        r'«([^»]+)»([^«]*)',
      ).allMatches(text.substring(start, end))) {
        final quoted = m[1]!.trim();
        final e3rab = _clean(m[2]!);
        final words = [
          for (final w in quoted.split(RegExp(r'\s+')))
            if (_skeleton(w).isNotEmpty) _skeleton(w),
        ];
        int? found;
        if (words.isNotEmpty) {
          for (final (loose, span) in [(false, 12), (true, 6)]) {
            final last = (at! + span).clamp(0, stream.length);
            for (var j = at; j < last && found == null; j++) {
              if (_same(stream[j].word, words.first, loose: loose)) found = j;
            }
            if (found != null) break;
          }
        }
        if (found == null) {
          // Not the next words of the ayahs (a sentence, «الجملة»): part of
          // the i'rab before it.
          if (lines.isNotEmpty) {
            final last = lines.removeLast();
            lines.add((
              word: last.word,
              e3rab: '${last.e3rab} «$quoted» $e3rab'.trim(),
              ayah: last.ayah,
            ));
          }
          continue;
        }
        at = found + words.length;
        lines.add((word: quoted, e3rab: e3rab, ayah: stream[found].ayah));
      }
    }
  }
  return [
    for (final l in lines)
      if (l.ayah == target && l.e3rab.isNotEmpty)
        (word: l.word, e3rab: l.e3rab),
  ];
}

/// The heading of the ayahs the text goes on to, with the first one's
/// number: [سورة البقرة (٢) : آية ٢٥٥]، [سورة البقرة (٢) : الآيات ١ الى ٥].
final _heading = RegExp(
  r'\[سورة [^\]]*?:\s*(?:آية|الآيات)\s*([٠-٩0-9]+)[^\]]*\]',
);

int _number(String digits) => int.parse(
  String.fromCharCodes(
    digits.runes.map((c) => c >= 0x0660 && c <= 0x0669 ? c - 0x0630 : c),
  ),
);

/// Where [heading] begins, with the surah's name written before it.
int _headStart(String text, Match heading) {
  final open = heading.start;
  final named = open == 0 ? -1 : text.lastIndexOf('سورة ', open - 1);
  return named >= 0 && !text.substring(named, open).contains(RegExp('[«»\n]'))
      ? named
      : open;
}

/// The letters compared: no vowels, and none of the letters the Uthmani
/// and the common spelling write differently (ٱلۡكِتَٰبُ، الْكِتابُ).
String _skeleton(String word) => word
    .replaceAll(RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]'), '')
    .replaceAll(RegExp('[أإآؤئ]'), 'ء')
    .replaceAll('ة', 'ه')
    .replaceAll(RegExp('[اٱويى]'), '')
    .replaceAll(RegExp('[^ء-ي]'), '');

bool _same(String a, String b, {required bool loose}) =>
    a == b ||
    loose &&
        a.length >= 3 &&
        b.length >= 3 &&
        (a.startsWith(b) || b.startsWith(a) || a.endsWith(b) || b.endsWith(a));

/// The i'rab of a word, without the heading of the ayahs after it.
String _clean(String text) => text
    .split(RegExp(r'(?:سورة [^\[«\n]*)?\['))
    .first
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
