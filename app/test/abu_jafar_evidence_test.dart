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

  group('a rule changing the body cited as a farsh: every reader', () {
    // «وَيَسۡتَنۢبُونَكَ» (يونس ٥٣): Abu Ja'far without the hamza, the others
    // and Hafs with it.
    for (final displayed in readers) {
      test('shown by $displayed', () {
        final cited = wordEvidence(
          repository: variants,
          ayah: quran.ayah(10, 53),
          word: 0,
          displayed: displayed,
          selected: readers,
          compared: {
            ...readers.difference({displayed}),
            'hafs',
          },
        );
        expect({
          for (final v in cited) v.riwayaId,
        }, containsAll({...readers, 'hafs'}));
      });
    }
    // A silah alone (عَلَيۡهِمُۥ) is no difference of the word: the one shown
    // alone.
    test('a silah alone cites the one shown', () {
      final cited = wordEvidence(
        repository: variants,
        ayah: quran.ayah(2, 7),
        word: 3,
        displayed: 'qalun',
        selected: readers,
        compared: {
          ...readers.difference({'qalun'}),
          'hafs',
        },
      );
      expect({for (final v in cited) v.riwayaId}, isNot(contains('hafs')));
    });
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

      test('Hafs is not noted against a silah alone (تفادوهم)', () {
        final notes = compareReadings(
          repository: variants,
          ayah: quran.ayah(2, 85),
          word: 17,
          displayed: 'ibn_wardan',
          selected: const ['hafs', 'bazzi', 'ibn_wardan'],
        ).where((v) => v.inHamesh);
        // Al-Bazzi reads it otherwise; Hafs reads it as the one shown.
        expect({for (final v in notes) v.riwayaId}, {'bazzi'});
      });

      test('«فنعما»: Qalun\'s two faces and Abu Ja\'far\'s one are apart', () {
        final notes = compareReadings(
          repository: variants,
          ayah: quran.ayah(2, 271),
          word: 3,
          displayed: 'qalun',
          selected: const ['ibn_wardan'],
        ).where((v) => v.inHamesh);
        expect({for (final v in notes) v.riwayaId}, {'ibn_wardan'});
      });

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
