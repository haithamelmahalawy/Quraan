import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final ayahs =
      (jsonDecode(File('assets/data/quran.json').readAsStringSync())
              as Map)['ayahs']
          as List;
  final glyphs =
      (jsonDecode(File('assets/data/qcf.json').readAsStringSync())
              as Map)['ayahs']
          as List;

  test('every ayah has a glyph slot for each word, its first not empty', () {
    for (final (i, a) in ayahs.indexed) {
      final words = (a[4] as String).split(' ');
      final slots = (glyphs[i][0] as List).cast<String>();
      expect(slots.length, words.length, reason: '${a[0]}:${a[1]}');
      // An empty slot is drawn with the word before: never the first.
      expect(slots.first, isNotEmpty, reason: '${a[0]}:${a[1]}');
    }
  });

  test(
    '«... أَنزَلۡنَٰهُ ... بَعۡدَ مَا» (الرعد ٣٧): a glyph for each word',
    () {
      // quran.com's kashida (أَنزَلْنَـٰهُ) counted as a letter moved them on,
      // and its «بَعْدَ مَا» is one word of two glyphs (the user, 2026-11-24).
      final i = ayahs.indexWhere((a) => a[0] == 13 && a[1] == 37);
      final slots = (glyphs[i][0] as List).cast<String>();
      expect(slots.where((s) => s.isEmpty), isEmpty);
      expect(slots[7].runes.length, 1);
      expect(slots[8].runes.length, 1);
      expect(slots[19].runes.length, 1);
    },
  );
}
