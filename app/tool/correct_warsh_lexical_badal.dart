import 'package:qiraat_mushaf/data/arabic.dart';
import 'package:qiraat_mushaf/data/warsh_badal.dart';

/// Re-evaluate badal wherever the lexical reading changes the word, while
/// leaving the independent farsh and other rules intact.
void correctWarshLexicalBadal(Map quran, List variants, {Map? sourceText}) {
  final actual = <String, String>{
    if (sourceText != null)
      for (final a in sourceText['ayahs'] as List)
        for (final (w, text) in (a[2] as List).indexed)
          '${a[0]}:${a[1]}:$w': text as String,
  };
  final base = <String, String>{
    for (final a in quran['ayahs'] as List)
      for (final (w, text) in (a[4] as String).split(' ').indexed)
        '${a[0]}:${a[1]}:$w': text,
  };
  final changed = <String, (List, String)>{};
  final at = <String, List<List>>{};
  for (final v in variants.cast<List>()) {
    (at['${v[0]}:${v[1]}:${v[2]}'] ??= []).add(v);
  }
  for (final raw in variants) {
    final v = raw as List;
    if (!const {'f', 'h'}.contains(v[5]) ||
        v[4] == '' ||
        v.length > 7 && !const {'', 'kharouf', 'naql'}.contains(v[7])) {
      continue;
    }
    final words = (v[4] as String).split(' ');
    for (var i = 0; i < (v[3] as int); i++) {
      final fallback = words.length == v[3]
          ? words[i]
          : i == 0
          ? v[4] as String
          : '';
      final key = '${v[0]}:${v[1]}:${(v[2] as int) + i}';
      changed[key] = (v, actual[key] ?? fallback);
    }
  }
  final remove = <List>{};
  for (final entry in changed.entries) {
    final (v, own) = entry.value;
    // A kashida drawing out the dagger alif (اُ۬لَٰـنَ) is no letter.
    var probe = madinahScript(own.replaceAll('ٰـ', 'ٰ'));
    final naql = (at[entry.key] ?? const <List>[]).where(
      (p) => p.length > 7 && p[7] == 'naql',
    );
    // Naql does not cancel badal. Restore only the hamza's diagnostic
    // spelling, without altering the displayed word or the source asset.
    if (naql.isNotEmpty) {
      final hafs = base[entry.key]!;
      final h = lettersOf(hafs), r = lettersOf(probe);
      final lam = naqlLetter(h);
      if (r.length == h.length) {
        for (var i = 0; i < h.length; i++) {
          if (('ءأإؤئ'.contains(h[i][0]) || h[i].contains('ٔ')) &&
              r[i].startsWith('ا')) {
            r[i] = h[i];
            // And the letter after it as Hafs marks it: the unread waw of
            // أُوْلَٰٓئِكَ (اُوْلَٰٓئِكَ, its damma moved) is no madd.
            if (i + 1 < h.length && h[i + 1][0] == r[i + 1][0]) {
              r[i + 1] = h[i + 1];
            }
          }
        }
        probe = r.join();
      } else if (lam != null && r.length > lam && r[lam].contains('ٰ')) {
        r[lam] = r[lam].replaceAll('ٰ', '');
        r.insert(lam + 1, h[lam + 1]);
        probe = r.join();
      } else if (lam != null &&
          r.length > lam + 1 &&
          r[lam + 1].startsWith('ا')) {
        r[lam + 1] = h[lam + 1];
        probe = r.join();
      } else if (r.isNotEmpty &&
          r.first.startsWith('ا') &&
          ('ءأإ'.contains(h.first[0]))) {
        probe = '${h.first}${r.join()}';
      }
    }
    final keep =
        own.isNotEmpty &&
        hasWarshBadal(probe, '${v[0]}:${v[1]}') &&
        !(v[0] == 53 && v[1] == 50 && v[2] == 3);
    final old = (at[entry.key] ?? const <List>[])
        .where((p) => p.length > 7 && p[7] == 'badal')
        .toList();
    if (!keep) {
      remove.addAll(old);
    } else if (old.isEmpty) {
      final word = int.parse(entry.key.split(':').last);
      variants.add([
        v[0],
        v[1],
        word,
        1,
        '',
        'u',
        'مد البدل: بالقصر والتوسط والإشباع',
        'badal',
      ]);
    }
  }
  variants.removeWhere(remove.contains);
}
