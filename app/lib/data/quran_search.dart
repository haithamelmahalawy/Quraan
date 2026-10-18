import 'arabic.dart';
import 'quran_repository.dart';
import '../models/quran.dart';

/// One place a search was found: the ayah, its page and the Hafs words the
/// match covers.
typedef SearchHit = ({Ayah ayah, int page, int from, int to});

/// Finds words or phrases in the Hafs text, however they are typed: the
/// comparison ignores diacritics and the spelling of alef and hamza (typed
/// الرحمن finds ٱلرَّحۡمَٰنِ), then, for what is still not found, waw and ya
/// as well (الصلاة finds ٱلصَّلَوٰةَ).
class QuranSearch {
  QuranSearch(QuranRepository quran)
    : _ayahs = [
        for (var p = 1; p <= QuranRepository.pageCount; p++)
          for (final a in quran.page(p)) _Indexed(a, p),
      ];

  final List<_Indexed> _ayahs;

  /// Every place [query] is found, in mushaf order (exact spellings first,
  /// then the looser ones); at most [limit].
  List<SearchHit> search(String query, {int limit = 1000}) {
    final words = query.trim().split(RegExp(r'\s+'));
    final strict = words.map(skeleton).where((w) => w.isNotEmpty).join(' ');
    if (strict.isEmpty) return const [];
    final loose = words.map(_loose).where((w) => w.isNotEmpty).join(' ');
    final hits = <SearchHit>[];
    final found = <(Ayah, int)>{};
    void scan(String q, _Text Function(_Indexed) text) {
      for (final a in _ayahs) {
        final t = text(a);
        for (
          var i = t.joined.indexOf(q);
          i >= 0;
          i = t.joined.indexOf(q, i + 1)
        ) {
          final from = t.wordAt(i), to = t.wordAt(i + q.length - 1) + 1;
          if (!found.add((a.ayah, from))) continue;
          hits.add((ayah: a.ayah, page: a.page, from: from, to: to));
          if (hits.length >= limit) return;
        }
      }
    }

    scan(strict, (a) => a.strict);
    // Shorter remains match almost anywhere.
    if (hits.length < limit && loose.replaceAll(' ', '').length >= 3) {
      scan(loose, (a) => a.loose);
    }
    return hits;
  }

  static String _loose(String word) =>
      skeleton(word).replaceAll(RegExp('[وي]'), '');
}

class _Indexed {
  _Indexed(this.ayah, this.page)
    : strict = _Text([for (final w in ayah.words) skeleton(w)]),
      loose = _Text([for (final w in ayah.words) QuranSearch._loose(w)]);

  final Ayah ayah;
  final int page;
  final _Text strict, loose;
}

/// An ayah's words joined by spaces, and where each word starts.
class _Text {
  _Text(List<String> words) : joined = words.join(' ') {
    var at = 0;
    for (final w in words) {
      _starts.add(at);
      at += w.length + 1;
    }
  }

  final String joined;
  final _starts = <int>[];

  /// The word the character at [i] belongs to.
  int wordAt(int i) {
    var w = 0;
    while (w + 1 < _starts.length && _starts[w + 1] <= i) {
      w++;
    }
    return w;
  }
}
