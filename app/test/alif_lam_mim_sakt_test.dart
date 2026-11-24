import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// «الٓمٓ ۝ أَحَسِبَ» (العنكبوت ١-٢): the mim's name ends sakin before the
/// hamza, Khalaf's sakt on the separated sakin by khulf; not Khallad's (the
/// user, 2026-11-24).
void main() {
  List rows(String id) =>
      ((jsonDecode(File('assets/data/qiraat/$id.json').readAsStringSync())
                  as Map)['variants']
              as List)
          .where((r) => r[0] == 29 && r[1] == 1 && r[7] == 'sakt')
          .toList();

  test('Khalaf: the sakt after «الٓمٓ», by khulf', () {
    final r = rows('khalaf_hamzah').single;
    expect(r[4], 'الٓمٓۜ');
    expect(r[6], startsWith('بالسكت على الساكن المفصول قبل الهمز بخلف عنه'));
  });

  test('Khallad: none', () {
    expect(rows('khallad'), isEmpty);
  });
}
