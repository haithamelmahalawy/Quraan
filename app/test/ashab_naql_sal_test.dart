import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/ui/usul_labels.dart';

/// «وَسۡـَٔلُواْ، فَسۡـَٔلِ» for al-Kisa'i and Khalaf al-'Ashir: «النقل» of the
/// usul, at Ibn Kathir's places and in his words, not the hamesh, though the
/// book tells it in its farsh (the user, 2026-11-14).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('al-Kisai and Khalaf read sal with naql as Ibn Kathir', () async {
    const ashab = ['abul_harith', 'duri_kisai', 'ishaq', 'idris'];
    final variants = VariantRepository({'bazzi', ...ashab});
    await variants.ensureLoaded(['bazzi', ...ashab]);
    bool naql(v) => v.description.startsWith('بنقل حركة الهمزة إلى السين');
    final his = [
      for (final v in variants.allOf('bazzi'))
        if (naql(v)) '${v.surah}:${v.ayah}:${v.word}',
    ];
    expect(his, hasLength(14));
    for (final id in ashab) {
      final rows = variants.allOf(id).where(naql).toList();
      expect([for (final v in rows) '${v.surah}:${v.ayah}:${v.word}'], his);
      for (final v in rows) {
        expect(v.isUsul, isTrue, reason: '$id ${v.surah}:${v.ayah}');
        expect(usulOf(v), ['النقل']);
      }
    }
  });
}
