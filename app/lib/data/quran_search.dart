import 'quran_repository.dart';
import '../models/quran.dart';

/// One place a search was found: the ayah, its page and the Hafs words the
/// match covers.
typedef SearchHit = ({Ayah ayah, int page, int from, int to});

/// Finds words or phrases in the Hafs text as they are typed (the user,
/// 2026-11-12): the comparison ignores diacritics and the hamzas (اشركوا and
/// أشركوا find أَشۡرَكُوٓاْ), the alif kept as a letter, so that شفعاؤ finds
/// شُفَعَٰٓؤُاْ, not شَفَٰعَة nor يَشۡفَعُ, and اشركوا not شُرَكَآؤُكُمۡ. The rasm's
/// dagger alif is read both as an alif and as none (الرحمن and الرحمان find
/// ٱلرَّحۡمَٰنِ), and a waw written for an alif as the alif (الصلاة finds
/// ٱلصَّلَوٰةَ). A word is matched from its start, or after the letters added
/// to it (وَ، فَ، بِ، لِ، كَ، سَ، ٱلۡ).
class QuranSearch {
  QuranSearch(QuranRepository quran)
    : _ayahs = [
        for (var p = quran.firstPage; p <= quran.lastPage; p++)
          for (final a in quran.page(p))
            // Once, on the page where it starts.
            if (quran.pageOf(a.surah, a.number) == p) _Indexed(a, p),
      ];

  final List<_Indexed> _ayahs;

  /// Every place [query] is found, in mushaf order; at most [limit].
  List<SearchHit> search(String query, {int limit = 1000}) {
    final q = query
        .trim()
        .split(RegExp(r'\s+'))
        .map((w) => searchForm(w, dagger: true))
        .where((w) => w.isNotEmpty)
        .join(' ');
    if (q.isEmpty) return const [];
    final hits = <SearchHit>[];
    final found = <(Ayah, int)>{};
    void scan(_Text Function(_Indexed) text) {
      for (final a in _ayahs) {
        final t = text(a);
        for (
          var i = t.joined.indexOf(q);
          i >= 0;
          i = t.joined.indexOf(q, i + 1)
        ) {
          final from = t.wordAt(i), to = t.wordAt(i + q.length - 1) + 1;
          // Not inside another word (شفعاؤ is not فَيَشۡفَعُواْ).
          final before = t.joined.substring(t.startOf(from), i);
          if (!RegExp(r'^[وفبلكسا]{0,4}$').hasMatch(before)) continue;
          if (!found.add((a.ayah, from))) continue;
          hits.add((ayah: a.ayah, page: a.page, from: from, to: to));
          if (hits.length >= limit) return;
        }
      }
    }

    scan((a) => a.withDagger);
    if (hits.length < limit) scan((a) => a.withoutDagger);
    return hits;
  }
}

/// [word] as the search compares it: its letters without diacritics or
/// hamzas, every alif one «ا», ى a ya, ة a ha. With [dagger], the rasm's
/// dagger alif an alif (and a waw it is written on, ٱلصَّلَوٰةَ, the alif);
/// without, none. Not after an alif maqsura (عَلَىٰ is على).
String searchForm(String word, {required bool dagger}) {
  final b = StringBuffer();
  var last = '';
  for (final c in word.runes) {
    final ch = String.fromCharCode(c);
    if (c == 0x0670) {
      if (dagger && last != 'ى') {
        final t = b.toString();
        if (last == 'و') {
          b
            ..clear()
            ..write(t.substring(0, t.length - 1));
        }
        b.write('ا');
      }
    } else if ('أإآٱا'.contains(ch)) {
      b.write('ا');
    } else if ('ءؤئ'.contains(ch)) {
      // The hamza and its seat, ignored.
    } else if (ch == 'ى' || c == 0x06CC || c == 0x06E6 || c == 0x06E7) {
      b.write('ي');
    } else if (c == 0x06E5) {
      b.write('و');
    } else if (ch == 'ة') {
      b.write('ه');
    } else if (c == 0x06A9) {
      b.write('ك');
    } else if (c >= 0x0621 && c <= 0x064A && c != 0x0640) {
      b.write(ch);
    } else {
      continue;
    }
    last = ch;
  }
  return b.toString();
}

class _Indexed {
  _Indexed(this.ayah, this.page)
    : withDagger = _Text([
        for (final w in ayah.words) searchForm(w, dagger: true),
      ]),
      withoutDagger = _Text([
        for (final w in ayah.words) searchForm(w, dagger: false),
      ]);

  final Ayah ayah;
  final int page;
  final _Text withDagger, withoutDagger;
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

  /// Where the word [w] starts.
  int startOf(int w) => _starts[w];

  /// The word the character at [i] belongs to.
  int wordAt(int i) {
    var w = 0;
    while (w + 1 < _starts.length && _starts[w + 1] <= i) {
      w++;
    }
    return w;
  }
}
