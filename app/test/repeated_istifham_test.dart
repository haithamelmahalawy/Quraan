import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';

// The repeated question (الرعد ٥): each reader's two ways in the usul, as
// Qalun's; nothing of it in the hamesh (the user, 2026-11-14).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test("al-Ra'd 5's repeated question told in the usul alone", () async {
    final variants = await VariantRepository.discover();
    const ids = ['qalun', 'warsh', 'abul_harith', 'duri_kisai'];
    await variants.ensureLoaded(ids);
    for (final id in ids) {
      for (final w in [4, 5, 6, 7]) {
        expect(
          variants.at([id], 13, 5, w).where((v) => v.inHamesh),
          isEmpty,
          reason: '$id $w',
        );
      }
      final ways = variants
          .at([id], 13, 5, 7)
          .singleWhere((v) => v.rule == 'tasheel_word')
          .usulWays;
      expect(ways, hasLength(2), reason: id);
    }
    expect(
      variants
          .at(['duri_kisai'], 13, 5, 4)
          .singleWhere((v) => v.rule == 'tasheel_word')
          .usulWays,
      ['الاستفهام في «أءذا» مع التحقيق', 'الإخبار في «إنا» بالتحقيق'],
    );
  });
}
