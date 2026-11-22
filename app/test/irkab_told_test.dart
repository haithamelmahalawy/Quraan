import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';

// «ٱرۡكَب مَّعَنَا» (هود ٤٢) under the idgham: every chosen reader told when
// they differ, Hafs «(بالإدغام)» too; nothing when they agree (the user,
// 2026-11-22).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late VariantRepository variants;
  late QuranRepository quran;
  setUpAll(() async {
    variants = await VariantRepository.discover();
    quran = await QuranRepository.load();
  });

  Future<Map<String, String>> told(Set<String> ids, {String? shown}) async {
    await variants.ensureLoaded(ids);
    final s = ReaderSettings.memory(
      selected: ids,
      mode: shown == null ? DisplayMode.hamesh : DisplayMode.replace,
    )..displayed = shown;
    final ayah = quran.ayah(11, 42);
    return {
      for (final v in irkabTold(
        variants.forBand({...s.selected, ?s.displayed}, 11, 42, 13),
        ayah,
        13,
        s,
      ))
        if (v.rule == 'idgham_saghir') v.riwayaId: v.bandNote,
    };
  }

  test('Khalaf al-Ashir with Hafs: both told', () async {
    expect(await told({'ishaq', 'idris'}), {
      'ishaq': 'بالإظهار',
      'idris': 'بالإظهار',
      'hafs': 'بالإدغام',
    });
  });

  test('an idgham reader beside them, with his own note', () async {
    final t = await told({'ishaq', 'susi'}, shown: 'ishaq');
    expect(t, {'ishaq': 'بالإظهار', 'susi': 'بالإدغام'});
  });

  test('all reading izhar: not told', () async {
    expect(await told({'ishaq', 'warsh'}, shown: 'ishaq'), isEmpty);
  });

  test('all reading idgham with Hafs: not told', () async {
    expect(await told({'susi'}), isEmpty);
  });

  test('a reader with both faces: told', () async {
    expect((await told({'qalun'})).keys, containsAll(['qalun', 'hafs']));
  });
}
