import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/reading_comparison.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository quran;
  late VariantRepository variants;
  const readers = {'qalun', 'bazzi', 'qunbul', 'ibn_wardan', 'ibn_jammaz'};
  setUpAll(() async {
    quran = await QuranRepository.load();
    variants = await VariantRepository.discover();
    await variants.ensureLoaded(readers.toList());
  });

  group('the word tapped cites every reader, whoever is shown', () {
    // «ٱلۡبُيُوتَ» (البقرة ١٨٩): Qalun and Ibn Kathir with the kasra, Abu
    // Ja'far with Hafs's damma and no row of his own.
    for (final displayed in readers) {
      test('shown by $displayed', () {
        final ayah = quran.ayah(2, 189);
        final cited = wordEvidence(
          repository: variants,
          ayah: ayah,
          word: 12,
          displayed: displayed,
          selected: readers,
          compared: readers.difference({displayed}),
        );
        expect({for (final v in cited) v.riwayaId}, containsAll(readers));
      });
    }
  });

  group(
    'the hamesh shows the word of who does not read a rule of its body',
    () {
      test(
        '«النبيئين» shown by Qalun: Abu Ja\'far\'s and Ibn Kathir\'s word',
        () {
          final ayah = quran.ayah(2, 61);
          final word = ayah.words.indexWhere(
            (w) => w.replaceAll(RegExp('[ً-ٰۖ-ۭـ]'), '').contains('لنبي'),
          );
          expect(word, isNonNegative);
          final notes = otherBodyNotes(variants, ayah, word, 'qalun', const [
            'ibn_wardan',
            'bazzi',
          ], const []);
          expect({for (final v in notes) v.riwayaId}, {'ibn_wardan', 'bazzi'});
          for (final v in notes) {
            expect(v.text, isNot(contains('ء')));
          }
        },
      );

      test('a silah alone adds no note', () {
        final ayah = quran.ayah(2, 191);
        final notes = otherBodyNotes(variants, ayah, 17, 'qalun', const [
          'ibn_wardan',
          'bazzi',
          'hafs',
        ], const []);
        expect(notes, isEmpty);
      });
    },
  );
}
