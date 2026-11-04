// An alif a reader adds to Hafs's word is written as the dagger alif, so the
// reading keeps the 'Uthmani rasm of the mushaf (خطيئَاتُهُ → خطيئَٰتُهُ،
// دِفَاعُ → دِفَٰعُ): a written alif stands only where Hafs's rasm has one.
// Run from app/: dart run tool/apply_dagger_alif.dart [--dry]
import 'dart:convert';
import 'dart:io';

/// The alif in all its forms: the wasl's, a hamza's seat, the madd's.
const _alifs = 'اٱأإآ';

/// The other letters an alif stands between (a hamza on a kashida, ـٔ, is
/// one of them).
final _letter = RegExp('[ء-ي]');

String _norm(String ch) => switch (ch) {
  'ى' || 'ے' => 'ي',
  'ئ' || 'ؤ' || 'ٔ' || 'ٕ' => 'ء',
  _ => ch,
};

bool _isLetter(String word, int i) {
  // Not the kashida, though within the letters' range.
  if (_alifs.contains(word[i]) || word[i] == 'ـ') return false;
  if (_letter.hasMatch(word[i])) return true;
  if (!'ٕٔ'.contains(word[i])) return false;
  // The hamza on a kashida, its vowel or dagger alif maybe before it (ـَٔ).
  var j = i - 1;
  while (j >= 0 && RegExp('[ً-ٰ]').hasMatch(word[j])) {
    j--;
  }
  return j >= 0 && word[j] == 'ـ';
}

/// The letters of [word] but its alifs, the written alifs in each gap, and
/// the gaps with a dagger alif.
(String, List<int>, Set<int>) _gaps(String word) {
  final letters = StringBuffer();
  final alifs = <int>[0];
  final daggers = <int>{};
  for (var i = 0; i < word.length; i++) {
    if (_alifs.contains(word[i])) {
      alifs[alifs.length - 1]++;
    } else if (word[i] == 'ٰ') {
      daggers.add(alifs.length - 1);
    } else if (_isLetter(word, i)) {
      letters.write(_norm(word[i]));
      alifs.add(0);
    }
  }
  return ('$letters', alifs, daggers);
}

/// The alifs [word] adds to Hafs's [hafs] where he reads none, neither
/// written nor dagger (قَٰلَ for قُلۡ, not عِبَٰدَهُ): a reading of its own.
bool addsAlif(String word, String hafs) {
  final (mine, myAlifs, myDaggers) = _gaps(word);
  final (his, hisAlifs, hisDaggers) = _gaps(hafs);
  if (mine != his) return false;
  for (var g = 1; g < myAlifs.length; g++) {
    final own = myAlifs[g] + (myDaggers.contains(g) ? 1 : 0);
    final theirs = hisAlifs[g] + (hisDaggers.contains(g) ? 1 : 0);
    if (own > theirs) return true;
  }
  return false;
}

/// [word] with each written alif Hafs's [hafs] has not in that place a dagger
/// one; unchanged where their letters differ (nothing sure to change), and
/// the alif of a tanween (قَلِيلٗا) or one written but not read (اْ) kept.
String daggerAlifWord(String word, String hafs) {
  final (mine, _, _) = _gaps(word);
  final (his, hisAlifs, _) = _gaps(hafs);
  if (mine != his) return word;
  final out = StringBuffer();
  var gap = 0;
  var seen = 0;
  for (var i = 0; i < word.length; i++) {
    final ch = word[i];
    if (_alifs.contains(ch)) {
      seen++;
      final before = i > 0 ? word[i - 1] : '';
      final after = i + 1 < word.length ? word[i + 1] : '';
      final keep =
          // The alif with the madd (تُمَآسُّوهُنَّ) the dagger one with it.
          !'اآ'.contains(ch) ||
          gap == 0 ||
          seen <= hisAlifs[gap] ||
          // A tanween's (قَلِيلٗا، بِيُوتاً).
          'ًٗ'.contains(before) && before.isNotEmpty ||
          'ًْٗ۟ۡ'.contains(after) && after.isNotEmpty;
      out.write(
        keep
            ? ch
            : ch == 'آ'
            ? 'ٰٓ'
            : 'ٰ',
      );
      // A vowel the source put on the alif (لآَئِكَةُ) is the letter's before.
      while (!keep && i + 1 < word.length && 'ًٌٍَُِ'.contains(word[i + 1])) {
        i++;
      }
      continue;
    }
    if (_isLetter(word, i)) {
      gap++;
      seen = 0;
    }
    out.write(ch);
  }
  return '$out';
}

/// [text] (of the Hafs words [hafs]) with its added alifs dagger ones.
String daggerAlif(String text, List<String> hafs) {
  final words = text.split(' ');
  if (words.length != hafs.length) return text;
  return [for (final (i, w) in words.indexed) daggerAlifWord(w, hafs[i])]
      .join(' ');
}

/// Applies it to the rows of a riwaya with a written text.
int applyDaggerAlif(Map quran, List rows) {
  final words = <String, String>{
    for (final x in quran['ayahs'] as List)
      for (final (i, w) in (x[4] as String).split(' ').indexed)
        '${x[0]}:${x[1]}:$i': w,
  };
  var changed = 0;
  for (final v in rows.cast<List>()) {
    final text = '${v[4]}';
    // Or the alif with the madd alone (تُمَآسُّوهُنَّ).
    if (!RegExp('[اآ]').hasMatch(text)) continue;
    final hafs = [
      for (var d = 0; d < (v[3] as num).toInt(); d++)
        words['${v[0]}:${v[1]}:${(v[2] as int) + d}'] ?? '',
    ];
    if (hafs.any((w) => w.isEmpty)) continue;
    // And a vowel doubled before a dagger alif by an earlier run (لََٰٓ).
    final out = daggerAlif(
      text,
      hafs,
    ).replaceAllMapped(RegExp('([ًٌٍَُِ])\\1(?=ٰ)'), (m) => m[1]!);
    if (out != text) {
      v[4] = out;
      changed++;
    }
  }
  return changed;
}

/// `--dry` writes nothing; `--report=<file>` lists, for each riwaya, the
/// words where it adds an alif Hafs does not read, before and after.
void main(List<String> args) {
  final dry = args.contains('--dry');
  final report = args
      .where((a) => a.startsWith('--report='))
      .map((a) => a.substring('--report='.length))
      .firstOrNull;
  final quran =
      jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
  final words = <String, String>{
    for (final x in quran['ayahs'] as List)
      for (final (i, w) in (x[4] as String).split(' ').indexed)
        '${x[0]}:${x[1]}:$i': w,
  };
  final added = <Map<String, Object>>[];
  for (final f in Directory(
    'assets/data/qiraat',
  ).listSync().whereType<File>()) {
    if (!f.path.endsWith('.json')) continue;
    final id = f.uri.pathSegments.last.replaceFirst('.json', '');
    final data = jsonDecode(f.readAsStringSync()) as Map;
    final rows = data['variants'] as List;
    final before = [for (final v in rows.cast<List>()) '${v[4]}'];
    final n = applyDaggerAlif(quran, rows);
    stdout.writeln('$id: $n');
    for (final (i, v) in rows.cast<List>().indexed) {
      final own = before[i].split(' ');
      for (final (d, w) in own.indexed) {
        final hafs = words['${v[0]}:${v[1]}:${(v[2] as int) + d}'];
        if (hafs == null || own.length != (v[3] as num).toInt()) continue;
        if (!addsAlif(w, hafs)) continue;
        added.add({
          'riwaya': id,
          'place': '${v[0]}:${v[1]}:${(v[2] as int) + d}',
          'hafs': hafs,
          'before': w,
          'after': '${v[4]}'.split(' ')[d],
          'how': '${v.length > 6 ? v[6] : ''}',
        });
      }
    }
    if (!dry && n > 0) f.writeAsStringSync(jsonEncode(data));
  }
  if (report != null) File(report).writeAsStringSync(jsonEncode(added));
}
