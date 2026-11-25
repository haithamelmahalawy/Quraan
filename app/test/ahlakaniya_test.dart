import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/reading_comparison.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';

/// «أَهۡلَكَنِيَ» (الملك ٢٨), Hafs shown and the ten readers chosen: Hamza's ya
/// told in the usul, Warsh's naql too; nothing in the hamesh (the user,
/// 2026-11-25).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('no hamesh line for a difference of the usul alone', () async {
    final quran = await QuranRepository.load();
    final variants = await VariantRepository.discover();
    await variants.ensureLoaded(variants.available);
    final rows = compareReadings(
      repository: variants,
      ayah: quran.ayah(67, 28),
      word: 3,
      displayed: null,
      selected: variants.available,
    );
    expect(rows.where((v) => v.inHamesh), isEmpty);
    expect(
      rows.where((v) => v.riwayaId == 'khallad' && v.rule == 'ya_idafa'),
      hasLength(1),
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
