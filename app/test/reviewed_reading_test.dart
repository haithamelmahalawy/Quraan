import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/manzumat.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/reading_comparison.dart';
import 'package:qiraat_mushaf/data/usul_text.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/quran.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reviewed hamza farsh stays lexical and explicit omissions survive', () {
    const farsh = Variant(
      riwayaId: 'ibn_dhakwan',
      surah: 98,
      ayah: 6,
      word: 9,
      count: 1,
      text: 'ٱلۡبَرِيٓئَةِ',
      kind: VariantKind.farsh,
      rule: 'reviewed_farsh',
      description: 'بالهمز',
    );
    expect(farsh.isUsul, isFalse);
    expect(farsh.inHamesh, isTrue);
    expect(farsh.canReplaceText, isTrue);
    const omission = Variant(
      riwayaId: 'hisham',
      surah: 57,
      ayah: 24,
      word: 9,
      count: 1,
      text: '',
      kind: VariantKind.farsh,
      rule: 'reviewed_farsh',
      description: 'حذف لفظ هو',
      omission: true,
    );
    expect(omission.canReplaceText, isTrue);
    expect(omission.withCertified().omission, isTrue);
  });

  test(
    'stop forms appear in their margin but never replace continuous text',
    () async {
      final quran = await QuranRepository.load();
      final repo = await VariantRepository.discover();
      await repo.ensureLoaded(['ruways']);
      final v = repo
          .at(['ruways'], 2, 29, 0)
          .where((v) => v.stopOnly && v.stopText.isNotEmpty)
          .first;
      expect(v.canReplaceText, isFalse);
      expect(usulReadingText(v, quran.ayah(2, 29), repo), v.stopText);
      expect(v.withCertified().stopText, v.stopText);
    },
  );

  test('Ruways ishmam opens the relevant Durrah evidence', () async {
    final poems = await Manzumat.load();
    final quran = await QuranRepository.load();
    final repo = await VariantRepository.discover();
    await repo.ensureLoaded(['ruways']);
    final names = [for (final s in quran.surahs) s.nameAr];
    final ishmam = repo
        .at(['ruways'], 2, 11, 1)
        .singleWhere((v) => v.rule == 'ishmam');
    final evidence = poems.referenceOf(ishmam, 'قِيلَ', 2, names);
    expect(evidence.poem, Poem.durrah);
    expect(evidence.mention, {62, 63});
    // Ya'qub's routine madd is known of the riwaya and no longer stored per
    // word: nothing is told at بما.
    expect(
      repo.at(['ruways'], 2, 4, 2).where((v) => v.rule == 'madd_munfasil'),
      isEmpty,
    );
  });

  test(
    'actual shared attakhadhtum is equal across all narrator directions',
    () async {
      final quran = await QuranRepository.load();
      final repo = await VariantRepository.discover();
      const ids = ['hafs', 'shubah', 'warsh', 'hisham', 'ibn_dhakwan'];
      await repo.ensureLoaded(ids);
      final ayah = quran.ayah(2, 51);
      for (final base in ids) {
        for (final selected in ids) {
          final differences = compareReadings(
            repository: repo,
            ayah: ayah,
            word: 6,
            displayed: base == 'hafs' ? null : base,
            selected: [selected],
          );
          expect(
            differences.isNotEmpty,
            (base == 'hafs') != (selected == 'hafs'),
            reason: '$base / $selected',
          );
        }
      }
      final shubah = repo
          .at(['shubah'], 2, 51, 6)
          .firstWhere((v) => v.text.isNotEmpty)
          .text;
      for (final id in ['hisham', 'ibn_dhakwan']) {
        expect(
          repo
              .at([id], 2, 51, 6)
              .firstWhere((v) => v.rule == 'idgham_saghir')
              .text,
          shubah,
        );
        final fromHafs = compareReadings(
          repository: repo,
          ayah: ayah,
          word: 6,
          displayed: null,
          selected: [id],
        );
        expect(fromHafs, hasLength(1));
        expect(fromHafs.single.rule, 'idgham_saghir');
        expect(fromHafs.single.isUsul, isTrue);
        expect(fromHafs.single.inHamesh, isFalse);
      }
    },
  );
}
