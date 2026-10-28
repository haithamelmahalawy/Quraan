import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/arabic.dart';

void main() {
  test(
    'completed quotations preserve every quoted letter and explicit mark',
    () {
      var checked = 0;
      for (final id in ['ruways', 'rawh']) {
        final d = jsonDecode(
          File('assets/data/qiraat/$id.json').readAsStringSync(),
        );
        for (final v in (d['variants'] as List).cast<List>()) {
          if (v.length < 9 || v[8]['vocalizationSource'] == null) continue;
          final before = lettersOf(v[8]['vocalizationSource'] as String);
          final after = lettersOf(v[4] as String);
          final reason = '$id ${v[0]}:${v[1]}:${v[2]} ${v[4]}';
          expect(after.length, before.length, reason: reason);
          for (var i = 0; i < before.length; i++) {
            expect(after[i][0], before[i][0], reason: reason);
            for (final c in before[i].runes.skip(1)) {
              expect(after[i].runes, contains(c), reason: reason);
            }
          }
          checked++;
        }
      }
      expect(checked, greaterThan(100));
    },
  );
  test(
    'partial quotations retain unchanged vowels and explicit changed endings',
    () {
      expect(
        madinahScript(
          completeReadingVowels('فلا خوفَ عليهُمْ', 'فَلَا خَوۡفٌ عَلَيۡهِمۡ'),
        ),
        'فَلَا خَوۡفَ عَلَيۡهُمۡ',
      );
      expect(completeReadingVowels('تُقبل', 'يُقۡبَلُ'), 'تُقۡبَلُ');
      expect(completeReadingVowels('إِنِّي', 'إِنِّيٓ'), 'إِنِّي');
      expect(completeReadingVowels('مَن رَّاقٍ', 'مَنۡ رَاقٍ'), 'مَن رَّاقٍ');
    },
  );
  test('both Yaqub assets retain full vowels in the reported farsh words', () {
    for (final id in ['ruways', 'rawh']) {
      final d = jsonDecode(
        File('assets/data/qiraat/$id.json').readAsStringSync(),
      );
      final rows = (d['variants'] as List).cast<List>();
      final fear = rows.firstWhere(
        (v) => v[0] == 2 && v[1] == 38 && v[2] == 12,
      );
      final accept = rows.firstWhere(
        (v) => v[0] == 2 && v[1] == 48 && v[2] == 9,
      );
      // Only the words read otherwise than Hafs («فَلَا» is not).
      expect(madinahScript(fear[4] as String), 'خَوۡفَ عَلَيۡهُمۡ');
      expect(madinahScript(accept[4] as String), 'تُقۡبَلُ');
    }
  });
}
