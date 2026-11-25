import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/models/qiraat_catalog.dart';
import 'package:qiraat_mushaf/models/quran.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';

/// «ءَا۬عۡجَمِيّٞ» (فصلت ٤٤): Hafs told under the readers of it in
/// «الهمزتان من كلمة», «بتسهيل الثانية» (the user, 2026-11-25).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Hafs joins a reader told in it', () async {
    final q = await QuranRepository.load();
    final ayah = q.ayah(41, 44);
    final hamza = Variant(
      riwayaId: 'khallad',
      surah: 41,
      ayah: 44,
      word: 8,
      count: 1,
      text: 'ءَأَعۡجَمِيّٞ',
      kind: VariantKind.hamza,
      rule: 'tasheel_word',
      description: 'بتحقيق الهمزتين',
    );
    final told = ajamiTold([hamza], ayah, 8).toList();
    expect(told, hasLength(2));
    expect(told.last.riwayaId, hafsId);
    expect(told.last.text, ayah.words[8]);
    expect(told.last.description, 'بتسهيل الثانية');
    expect(isHafsAjami(told.last), isTrue);
    expect(ajamiTold(const [], ayah, 8), isEmpty);
    expect(ajamiTold([hamza], ayah, 7), [hamza]);
  });
}
