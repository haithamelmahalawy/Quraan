// A row covers the Hafs words its text reads: the page replaces every word a
// row counts, so a source's row told with the word next to it (يَامُرُكُمُ over
// «يَأۡمُرُكُمۡ أَن») would lose that word. The text is matched to Hafs's words by
// its letters, and the row put on those alone. What is really read as one word
// (مَالِيَ for «مَا لِيٓ», وَأَن for «أَوۡ أَن») keeps both.
// Run from app/: dart run tool/apply_word_span.dart [--dry]
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

String _key(String t) => t
    .replaceAll(RegExp('[ً-ٰٟۖ-ۭـٕٔ]'), '')
    .replaceAll(RegExp('[اأإآٱءئؤ]'), '')
    .replaceAll(RegExp('[ىے]'), 'ي')
    .replaceAll('ة', 'ت');

/// The share of letters two keys have in order.
double _alike(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  var row = List.filled(b.length + 1, 0);
  for (var i = 0; i < a.length; i++) {
    final next = List.filled(b.length + 1, 0);
    for (var j = 0; j < b.length; j++) {
      next[j + 1] = a[i] == b[j] ? row[j] + 1 : math.max(row[j + 1], next[j]);
    }
    row = next;
  }
  return row[b.length] / math.max(a.length, b.length);
}

/// Puts each row of [rows] on the words its text reads; the number changed.
int applyWordSpan(Map quran, List rows) {
  final words = <String, List<String>>{
    for (final x in quran['ayahs'] as List)
      '${x[0]}:${x[1]}': (x[4] as String).split(' '),
  };
  var changed = 0;
  final added = <List>[];
  for (final v in rows.cast<List>()) {
    final text = '${v[4]}'.trim();
    final count = (v[3] as num).toInt();
    if (text.isEmpty || text.contains('[')) continue;
    final own = text.split(RegExp(r'\s+'));
    if (own.length >= count) continue;
    // The word left out is what it tells (ٱلۡغَنِيُّ ٱلۡحَمِيدُ «بحذف هو»).
    if ('${v.length > 6 ? v[6] : ''}'.startsWith('بحذف هو')) continue;
    final ayah = words['${v[0]}:${v[1]}'];
    final from = v[2] as int;
    if (ayah == null || from + count > ayah.length) continue;
    final hafs = ayah.sublist(from, from + count).map(_key).toList();
    final keys = own.map(_key).toList();
    // The best place for its words, each to one word...
    var at = 0;
    var best = -1.0;
    var worst = 0.0;
    for (var o = 0; o + keys.length <= count; o++) {
      final scores = [
        for (var i = 0; i < keys.length; i++) _alike(keys[i], hafs[o + i]),
      ];
      final sum = scores.reduce((a, b) => a + b);
      if (sum > best) {
        best = sum;
        at = o;
        worst = scores.reduce(math.min);
      }
    }
    // ...or its last word two of Hafs's read as one.
    var merged = -1;
    final n = keys.length;
    for (var o = 0; o + n < count; o++) {
      final head = [
        for (var i = 0; i < n - 1; i++) _alike(keys[i], hafs[o + i]),
      ];
      final last = _alike(keys[n - 1], hafs[o + n - 1] + hafs[o + n]);
      final single = _alike(keys[n - 1], hafs[o + n - 1]);
      final other = _alike(keys[n - 1], hafs[o + n]);
      if (last > math.max(single, other) + .1 &&
          last >= .7 &&
          head.every((s) => s >= .5)) {
        merged = o;
        break;
      }
    }
    final int word, span;
    if (merged >= 0) {
      word = from + merged;
      span = n + 1;
    } else if (worst >= .6) {
      word = from + at;
      span = n;
    } else {
      continue;
    }
    if (word == from && span == count) continue;
    // One word told for two places (كَرۡهٗا «في الكلمتين»): each its own row.
    if (n == 1 && merged < 0) {
      for (var i = 0; i < count; i++) {
        if (from + i != word && hafs[i] == hafs[at] && hafs[i].isNotEmpty) {
          added.add(
            [...v]
              ..[2] = from + i
              ..[3] = 1,
          );
        }
      }
    }
    v[2] = word;
    v[3] = span;
    changed++;
  }
  int order(List v) =>
      (v[0] as int) * 1000000 + (v[1] as int) * 1000 + (v[2] as int);
  for (final v in added) {
    final next = rows.indexWhere((o) => order(o as List) > order(v));
    rows.insert(next < 0 ? rows.length : next, v);
  }
  return changed;
}

void main(List<String> args) {
  final dry = args.contains('--dry');
  final quran =
      jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
  // The others' sources are still to be verified, some with a wording for text.
  for (final id in const ['ibn_wardan', 'ibn_jammaz']) {
    final f = File('assets/data/qiraat/$id.json');
    final data = jsonDecode(f.readAsStringSync()) as Map;
    final rows = data['variants'] as List;
    final n = applyWordSpan(quran, rows);
    final left = [
      for (final v in rows.cast<List>())
        if ('${v[4]}'.trim().isNotEmpty &&
            '${v[4]}'.trim().split(RegExp(r'\s+')).length < (v[3] as num))
          '${v[0]}:${v[1]}:${v[2]}+${v[3]} ${v[4]} | ${v.length > 6 ? v[6] : ''}',
    ];
    stdout.writeln(
      '${f.uri.pathSegments.last}: $n, one for more: ${left.length}',
    );
    if (!dry && n > 0) f.writeAsStringSync(jsonEncode(data));
  }
}
