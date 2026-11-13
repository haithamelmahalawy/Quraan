import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/ui/usul_labels.dart';

/// Shu'bah's «زكرياء», its seven places: all in the usul, «الهمز المفرد» by
/// its added hamza, one description, none in the hamesh (the user,
/// 2026-11-13).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Shubah reads Zakariyya with the added hamza in the usul', () async {
    final variants = VariantRepository({'shubah'});
    await variants.ensureLoaded(['shubah']);
    final rows = variants
        .allOf('shubah')
        .where((v) => v.text.contains('زَكَرِي'))
        .toList();
    expect(
      [for (final v in rows) '${v.surah}:${v.ayah}:${v.word}'],
      ['3:37:8', '3:37:12', '3:38:2', '6:85:0', '19:2:4', '19:7:0', '21:89:0'],
    );
    for (final v in rows) {
      expect(v.isUsul, isTrue, reason: '${v.surah}:${v.ayah}');
      expect(usulOf(v), ['الهمز المفرد (زيادة الهمزة)']);
      expect(v.description, 'بزيادة الهمزة والمد');
    }
  });

  // «ٱءۡتُونِي» twice in 18:96, both in the hamesh alike, the first drawn as
  // it is, without the madd (the user, 2026-11-13).
  test('Shubah reads both of 18:96 in the hamesh', () async {
    final variants = VariantRepository({'shubah'});
    await variants.ensureLoaded(['shubah']);
    final rows = variants
        .allOf('shubah')
        .where(
          (v) => v.surah == 18 && v.ayah == 96 && v.text.contains('تُونِي'),
        )
        .toList();
    expect([for (final v in rows) v.word], [0, 15]);
    for (final v in rows) {
      expect(v.isUsul, isFalse, reason: '${v.word}');
      expect(v.description, rows.first.description);
    }
    expect(rows.first.text, 'ٱءۡتُونِي');
  });
}
