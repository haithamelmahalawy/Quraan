import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/reading_comparison.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/data/manzumat.dart';
import 'package:qiraat_mushaf/data/kharouf.dart';
import 'package:qiraat_mushaf/models/quran.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository quran;
  late VariantRepository repository;
  setUpAll(() async {
    quran = await QuranRepository.load();
    repository = await VariantRepository.discover();
    await repository.ensureLoaded(repository.available);
  });

  test('explicit ghunna rules remain available for word details', () {
    final readings = compareReadings(
      repository: repository,
      ayah: quran.ayah(2, 105),
      word: 9,
      displayed: null,
      selected: ['khalaf_hamzah'],
    );
    expect(readings.any((v) => v.rule == 'ghunna'), isTrue);
  });

  test(
    'an implicit Hafs agreement still resolves the selected narrator evidence',
    () async {
      final a = quran.ayah(5, 95);
      final reading = compareReadings(
        repository: repository,
        ayah: a,
        word: 12,
        displayed: 'warsh',
        selected: ['shubah'],
      ).single;
      final poems = await Manzumat.load();
      final book = await Kharouf.load();
      final ref = poems.referenceOf(reading, a.words[12], 5, [
        for (final s in quran.surahs) s.nameAr,
      ], entries: book.at(5, 95, 12));
      expect(reading.riwayaId, 'shubah');
      expect(ref.poem, Poem.shatibiyya);
      expect(ref.fromBook, isTrue);
      expect(ref.mention, isNotEmpty);
    },
  );

  test(
    'every narrator is compared against every base at fajaazaa and mithl',
    () {
      const withoutTanween = {
        'qalun',
        'warsh',
        'bazzi',
        'qunbul',
        'duri_abuamr',
        'susi',
        'hisham',
        'ibn_dhakwan',
        'ibn_wardan',
        'ibn_jammaz',
      };
      final ids = {'hafs', ...repository.available};
      expect(ids, hasLength(20));
      for (final base in ids) {
        for (final w in [12, 13]) {
          final compared = compareReadings(
            repository: repository,
            ayah: quran.ayah(5, 95),
            word: w,
            displayed: base == 'hafs' ? null : base,
            selected: ids,
          );
          final expected = ids
              .where(
                (id) =>
                    withoutTanween.contains(id) !=
                    withoutTanween.contains(base),
              )
              .toSet();
          expect(
            compared.where((v) => v.inHamesh).map((v) => v.riwayaId).toSet(),
            expected,
            reason: '$base, word $w',
          );
          expect(compared.every((v) => v.riwayaId != base), isTrue);
        }
      }
    },
  );

  test(
    'agreement with the displayed reading is not listed as a difference',
    () {
      final compared = compareReadings(
        repository: repository,
        ayah: quran.ayah(5, 95),
        word: 12,
        displayed: 'warsh',
        selected: ['warsh', 'qalun'],
      );
      expect(compared.where((v) => v.inHamesh), isEmpty);
    },
  );

  test(
    'letters, vowels and tanween are compared without font spelling noise',
    () {
      expect(readingTextKey('هَدۡيَۢا'), readingTextKey('هَدْياَۢ'));
      expect(
        readingTextKey('ملِكِ', baseline: 'مَٰلِكِ'),
        readingTextKey('مَلِكِ'),
      );
      expect(
        readingTextKey('مَرْقَدِنَاۜ'),
        isNot(readingTextKey('مَرْقَدِنَا')),
      );
      expect(readingTextKey('مِّثْلِ'), readingTextKey('مِثۡلِ'));
      expect(readingTextKey('مِثْلِ'), isNot(readingTextKey('مِثْلُ')));
      expect(readingTextKey('مَلِكِ'), isNot(readingTextKey('مَٰلِكِ')));
      expect(readingTextKey('فَجَزَآءُ'), isNot(readingTextKey('فَجَزَآءٞ')));
      expect(
        readingTextKey('فجزآءُ مثلِ', baseline: 'فَجَزَآءٞ مِّثۡلُ'),
        readingTextKey('فَجَزَآءُ مِثْلِ'),
      );
      expect(
        readingTextKey('ٱلرَّسُولَا۠'),
        isNot(readingTextKey('ٱلرَّسُولَا')),
      );
    },
  );

  test('overlapping single and multiword deltas compare the whole span', () {
    final a = Ayah(
      surah: 1,
      number: 1,
      page: 1,
      juz: 1,
      words: ['عَلَيْهِ', 'بِمَا', 'قَالَ'],
    );
    Variant v(
      String id,
      int word,
      int count,
      String text,
      String description,
    ) => Variant(
      riwayaId: id,
      surah: 1,
      ayah: 1,
      word: word,
      count: count,
      text: text,
      kind: VariantKind.farsh,
      description: description,
    );
    final fake = _Variants([
      v('base', 0, 2, 'عَلَيْهُ بِمَا', 'بضم الهاء'),
      v('same', 0, 1, 'عَلَيْهُ', 'بالضم'),
    ]);
    for (final word in [0, 1]) {
      final compared = compareReadings(
        repository: fake,
        ayah: a,
        word: word,
        displayed: 'base',
        selected: ['base', 'same', 'unchanged'],
      );
      expect(compared, hasLength(1));
      expect(compared.single.riwayaId, 'unchanged');
      expect(compared.single.word, 0);
      expect(compared.single.count, 2);
      expect(compared.single.text, 'عَلَيْهِ بِمَا');
      expect(compared.single.inHamesh, isTrue);
    }
  });

  test('omissions remain differences in both directions', () {
    final a = Ayah(surah: 1, number: 1, page: 1, juz: 1, words: ['هُوَ']);
    final fake = _Variants([
      const Variant(
        riwayaId: 'omit',
        surah: 1,
        ayah: 1,
        word: 0,
        count: 1,
        text: '',
        kind: VariantKind.farsh,
      ),
    ]);
    final restored = compareReadings(
      repository: fake,
      ayah: a,
      word: 0,
      displayed: 'omit',
      selected: ['unchanged'],
    ).single;
    expect(restored.text, 'هُوَ');
    expect(restored.inHamesh, isTrue);
    final omitted = compareReadings(
      repository: fake,
      ayah: a,
      word: 0,
      displayed: 'unchanged',
      selected: ['omit'],
    ).single;
    expect(omitted.text, isEmpty);
    expect(omitted.canReplaceText, isTrue);
  });
}

class _Variants extends VariantRepository {
  _Variants(this.rows) : super({'base', 'same', 'unchanged', 'omit'});
  final List<Variant> rows;
  @override
  bool isLoaded(String id) => available.contains(id);
  @override
  Iterable<Variant> at(Iterable<String> ids, int surah, int ayah, int word) =>
      rows.where(
        (v) =>
            ids.contains(v.riwayaId) &&
            v.surah == surah &&
            v.ayah == ayah &&
            v.word <= word &&
            word < v.word + v.count,
      );
}
