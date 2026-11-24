import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// «ٱلظُّنُونَاْ، ٱلرَّسُولَاْ، ٱلسَّبِيلَاْ» (الأحزاب ١٠، ٦٦، ٦٧) of Hamza,
/// Ya'qub and Abu 'Amr: the alif drawn, the round sukun over it, the note
/// «بحذف الألف وصلاً ووقفًا» (the user, 2026-11-25).
/// The letters and marks, whatever their order.
String sorted(String s) => (s.split('')..sort()).join();

void main() {
  test('the alif drawn with the round sukun', () {
    const words = {
      (10, 15): 'ٱلظُّنُونَاْ',
      (66, 10): 'ٱلرَّسُولَاْ',
      (67, 7): 'ٱلسَّبِيلَاْ',
    };
    for (final id in [
      'khalaf_hamzah',
      'khallad',
      'ruways',
      'rawh',
      'duri_abuamr',
      'susi',
    ]) {
      final rows =
          (jsonDecode(File('assets/data/qiraat/$id.json').readAsStringSync())
                  as Map)['variants']
              as List;
      for (final MapEntry(key: (a, w), value: text) in words.entries) {
        final r = rows.where((r) => r[0] == 33 && r[1] == a && r[2] == w);
        expect(r, hasLength(1), reason: '$id $a');
        expect(sorted(r.single[4] as String), sorted(text), reason: '$id $a');
        expect(
          r.single[6],
          startsWith('بحذف الألف وصلاً ووقف'),
          reason: '$id $a',
        );
      }
    }
  });
}
