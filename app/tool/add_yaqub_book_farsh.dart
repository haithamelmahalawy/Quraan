// Adds to Ya'qub's riwayat (Ruways, Rawh) the farsh readings the certified
// book «التسهيل لقراءات التنزيل» states for them and their files lack
// (2:105 «أن يُنْزَل», 2:83 «حَسَناً», ...). Their files are reviewed, so
// the app does not merge the book itself; words a reading of the file
// already covers are left as they are.
//
//   dart run tool/add_yaqub_book_farsh.dart
import 'dart:convert';
import 'dart:io';

import 'package:qiraat_mushaf/data/arabic.dart';

import 'build_data.dart' as data show describe, currentRiwaya;

void main() {
  final quran = jsonDecode(
    File('assets/data/quran.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final words = <String, List<String>>{
    for (final a in quran['ayahs'] as List)
      '${a[0]}:${a[1]}': (a[4] as String).split(' '),
  };
  final book = jsonDecode(
    File('assets/data/kharouf.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  for (final id in ['ruways', 'rawh']) {
    final file = File('assets/data/qiraat/$id.json');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final variants = json['variants'] as List
      // This tool's own readings, made again.
      ..removeWhere(
        (v) =>
            v.length > 8 &&
            v[8] is Map &&
            (v[8] as Map)['source'] == 'kharouf' &&
            (v[8] as Map).containsKey('vocalizationSource'),
      );
    final covered = <String>{
      for (final v in variants)
        for (var w = v[2] as int; w < (v[2] as int) + (v[3] as int); w++)
          '${v[0]}:${v[1]}:$w',
    };
    data.currentRiwaya = id;
    var added = 0;
    for (final p in ((book['riwayat'] as Map)[id] as List? ?? const [])) {
      final (s, a, w, c) = (p[0] as int, p[1] as int, p[2] as int, p[3] as int);
      final quoted = p[4] as String;
      if (p[6] != 'farsh' || quoted.isEmpty) continue;
      if ([for (var i = w; i < w + c; i++) '$s:$a:$i'].any(covered.contains)) {
        continue;
      }
      final ayah = words['$s:$a'];
      if (ayah == null || w + c > ayah.length) continue;
      final hafs = ayah.sublist(w, w + c).join(' ');
      // The book's tanween of fath on the alef (حَسَناً) goes on the letter
      // before it, as in the Madinah script (حَسَنًا), before the rest of
      // the vowels are completed from Hafs.
      final own = quoted.replaceAllMapped(
        RegExp('َ?اً(?=\\s|\$)'),
        (_) => 'ًا',
      );
      final text = _oneTanween(completeReadingVowels(own, hafs));
      final how = p[5] as String;
      final description = _withoutMadd(
        _says(how) ? how : data.describe(hafs, text),
      );
      variants.add([
        s,
        a,
        w,
        c,
        text,
        'f',
        description,
        '',
        {'source': 'kharouf', 'vocalizationSource': own},
      ]);
      for (var i = w; i < w + c; i++) {
        covered.add('$s:$a:$i');
      }
      added++;
      if (added <= 6) stdout.writeln('$id $s:$a $hafs → $text ($description)');
    }
    variants.sort(
      (x, y) => (x[0] as int) != (y[0] as int)
          ? (x[0] as int) - (y[0] as int)
          : (x[1] as int) != (y[1] as int)
          ? (x[1] as int) - (y[1] as int)
          : (x[2] as int) - (y[2] as int),
    );
    file.writeAsStringSync(jsonEncode(json));
    stdout.writeln('$id: $added added');
  }
}

/// The book's own vowel wins over the one completed from Hafs: one tanween
/// per letter (حَسَنٗاً → حَسَنًا).
String _oneTanween(String text) => text
    .replaceAllMapped(RegExp('([ٖٗٞ])([ً-ٍ])'), (m) => m[2]!)
    .replaceAllMapped(RegExp('([ً-ٍ])([ٖٗٞ])'), (m) => m[1]!)
    .replaceAllMapped(RegExp('[ٖٗٞ](?=ا[ً-ٍ])'), (m) => '');

/// Whether the book's wording tells how the word is read, not only where
/// (معاً، وصلاً ووقفاً).
bool _says(String how) =>
    how.isNotEmpty &&
    !RegExp(r'^(معاً|معا|وصلاً|وقفاً|وصلاً ووقفاً|كله|حيث وقع|[،\s])*$')
        .hasMatch(how);

/// Ya'qub's madd is known of the riwaya: not told at each word.
String _withoutMadd(String description) => description
    .replaceAll(RegExp(r' و(ال)?(قصر|مد)(?=\s|$)'), '')
    .replaceAll(RegExp(r'^ب(ال)?(قصر|مد) و'), 'ب');
