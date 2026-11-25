import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/ui/usul_labels.dart';

/// «ءَأَن كَانَ» (القلم ١٤) (the user, 2026-11-25): «بزيادة همزة استفهام» in the
/// hamesh, with each riwaya's way with the two hamzas; the easing ones told in
/// «الهمزتان من كلمة» too, the ones reading both whole not.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late VariantRepository variants;
  setUpAll(() async {
    variants = await VariantRepository.discover();
    await variants.ensureLoaded(variants.available);
  });

  qawariranAndSalasil(() => variants);

  test('the hamesh and the usul of each riwaya', () {
    const added = 'بزيادة همزة استفهام';
    for (final (id, hamesh, usul) in [
      ('khalaf_hamzah', added, null),
      ('khallad', added, null),
      ('shubah', added, null),
      ('rawh', added, null),
      (
        'hisham',
        '$added مع تسهيل الهمزة الثانية مع الإدخال',
        'بتسهيل الهمزة الثانية مع الإدخال',
      ),
      (
        'ibn_wardan',
        '$added مع تسهيل الهمزة الثانية مع الإدخال',
        'بتسهيل الهمزة الثانية مع الإدخال',
      ),
      (
        'ibn_dhakwan',
        '$added مع تسهيل الهمزة الثانية',
        'بتسهيل الهمزة الثانية بلا إدخال',
      ),
      (
        'ruways',
        '$added مع تسهيل الهمزة الثانية',
        'بتسهيل الهمزة الثانية بلا إدخال',
      ),
    ]) {
      final rows = variants.at([id], 68, 14, 0).where((v) => !v.stopOnly);
      final farsh = rows.where((v) => !v.isUsul).single;
      expect(farsh.description, hamesh, reason: id);
      expect(farsh.bookWujuh, isEmpty, reason: id);
      final told = rows.where((v) => v.rule == 'tasheel_word');
      if (usul == null) {
        expect(told, isEmpty, reason: id);
      } else {
        expect(told.single.description, usul, reason: id);
        expect(
          usulOf(told.single).single,
          startsWith('الهمزتان من كلمة'),
          reason: id,
        );
      }
    }
  });
}

/// The first «قَوَارِيرَاْ» (الإنسان ١٥) of Hamza and Ruways in the hamesh, the
/// second as Hafs's; «سَلَٰسِلَاْ» drawn as Hafs's (the user, 2026-11-25).
void qawariranAndSalasil(VariantRepository Function() variants) {
  test('«قَوَارِيرَاْ» and «سَلَٰسِلَاْ»', () {
    for (final id in ['khalaf_hamzah', 'khallad', 'ruways']) {
      final first = variants().at([id], 76, 15, 7).where((v) => !v.isUsul);
      expect(first.single.text, 'قَوَارِيرَاْ', reason: id);
      expect(
        first.single.description,
        'بترك التنوين وصلًا وبالراء وقفًا',
        reason: id,
      );
      expect(
        variants().at([id], 76, 16, 0).where((v) => !v.isUsul),
        isEmpty,
        reason: id,
      );
    }
    for (final id in ['khalaf_hamzah', 'khallad', 'ruways', 'qunbul']) {
      expect(
        variants().at([id], 76, 4, 3).where((v) => !v.isUsul).single.text,
        'سَلَٰسِلَاْ',
        reason: id,
      );
    }
  });
}
