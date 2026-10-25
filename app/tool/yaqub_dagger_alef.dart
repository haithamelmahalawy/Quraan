// Ya'qub's riwayat (Ruways, Rawh): their farsh quotations completed with
// the vowels of Hafs, and an alef a reading adds to the written
// word (دِفَاعُ, rasm دفع) is written as the dagger alef over the letter
// before it (دِفَٰعُ), keeping the rasm of the Madinah mushaf. Run it after
// any change of their readings (tool/add_yaqub_book_farsh.dart).
//
//   dart run tool/yaqub_dagger_alef.dart
import 'dart:convert';
import 'dart:io';

import 'package:qiraat_mushaf/data/arabic.dart';

void main() {
  final quran = jsonDecode(
    File('assets/data/quran.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final words = <String, List<String>>{
    for (final a in quran['ayahs'] as List)
      '${a[0]}:${a[1]}': (a[4] as String).split(' '),
  };
  for (final id in ['rawh', 'ruways']) {
    final file = File('assets/data/qiraat/$id.json');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    var changed = 0;
    for (final v in json['variants'] as List) {
      final text = v[4] as String;
      if (text.isEmpty) continue;
      final hafs = words['${v[0]}:${v[1]}']!.sublist(
        v[2] as int,
        (v[2] as int) + (v[3] as int),
      );
      // A quotation of the farsh short of its vowels (زكريآءُ) takes those
      // of Hafs for the letters they share, as the page writes it.
      if (const {'f', 'h'}.contains(v[5]) &&
          text.split(RegExp(r'\s+')).length == hafs.length) {
        final complete = completeReadingVowels(text, hafs.join(' '));
        if (complete != text) {
          v[4] = complete;
          changed++;
        }
      }
      final daggered = withDaggerAlef(v[4] as String, hafs);
      if (daggered == null) continue;
      v[4] = daggered;
      // The quotation the text was completed from, written the same way.
      if (v.length > 8 && v[8] is Map && v[8]['vocalizationSource'] is String) {
        v[8]['vocalizationSource'] =
            withDaggerAlef(v[8]['vocalizationSource'] as String, hafs) ??
            v[8]['vocalizationSource'];
      }
      changed++;
    }
    file.writeAsStringSync(jsonEncode(json));
    stdout.writeln('$id: $changed');
  }
}

/// [reading] with each alef it adds to the words of [hafs] as a dagger
/// alef; null when it adds none (or its words are not aligned with them).
String? withDaggerAlef(String reading, List<String> hafs) {
  final own = reading.split(RegExp(r'\s+'));
  if (own.length != hafs.length) return null;
  var changed = false;
  final out = [
    for (var i = 0; i < own.length; i++) _word(own[i], hafs[i]) ?? own[i],
  ];
  for (var i = 0; i < own.length; i++) {
    if (out[i] != own[i]) changed = true;
  }
  return changed ? out.join(' ') : null;
}

final _mark = RegExp('[ً-ٰٟۖ-ۭـ]');

List<String> _clusters(String word) {
  final out = <String>[];
  for (final c in word.split('')) {
    if (_mark.hasMatch(c) && out.isNotEmpty) {
      out[out.length - 1] += c;
    } else {
      out.add(c);
    }
  }
  return out;
}

String _base(String cluster) =>
    const {'ٱ', 'أ', 'إ', 'آ'}.contains(cluster[0]) ? 'ا' : cluster[0];

String? _word(String own, String hafs) {
  final r = _clusters(own), h = _clusters(hafs);
  if (r.length != h.length + 1) return null;
  for (var k = 1; k < r.length; k++) {
    if (r[k][0] != 'ا') continue;
    final rest = [...r.sublist(0, k), ...r.sublist(k + 1)];
    if (rest.map(_base).join() != h.map(_base).join()) continue;
    // The letter before carries the fatha and the dagger alef.
    var before = r[k - 1].replaceAll(RegExp('[ُِْٰۡ]'), '');
    if (!before.contains('َ')) before += 'َ';
    before += 'ٰ';
    // A madda on the alef stays on the dagger alef (طَٰٓئِر).
    if (r[k].contains('ٓ')) before += 'ٓ';
    return [...r.sublist(0, k - 1), before, ...r.sublist(k + 1)].join();
  }
  return null;
}
