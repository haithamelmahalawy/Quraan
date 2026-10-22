import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/quranpedia_qiraat.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/quran.dart';

import '../tool/build_data.dart' as data;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('silah omission preserves the kasra; a sakin ha stays distinct', () {
    expect(data.describe('فِيهِۦ', 'فِيهِ'), 'بترك صلة الهاء');
    expect(data.describe('يُؤَدِّهِۦ', 'يُؤَدِّهۡ'), contains('إسكان الهاء'));
  });

  test('iqlab tanween and an added interrogative hamza are farsh', () {
    expect(data.classify('مَّوَدَّةَ', 'مَّوَدَّةَۢ'), 'f');
    expect(
      data.describe('مَّوَدَّةَ', 'مَّوَدَّةَۢ'),
      'بتنوين التاء بالفتح والإقلاب',
    );
    expect(data.classify('إِنَّكُمۡ', 'أَءِنَّكُمۡ'), 'f');
    expect(data.describe('إِنَّكُمۡ', 'أَءِنَّكُمۡ'), 'بزيادة همزة استفهام');
    expect(data.classify('أَءِنَّكُمۡ', 'إِنَّكُمۡ'), 'f');
    expect(data.classify('يَأۡتُونَ', 'يَاتُونَ'), 'h');
    expect(
      QuranpediaQiraat.kindOf(
        'مَوَدَّةً بَيْنَكُمُ',
        'بتنوين التاء بالفتح ونصب النون وصلة ميم الجمع',
        'مودهبينكم',
      ),
      VariantKind.farsh,
    );
    expect(
      QuranpediaQiraat.kindOf(
        'أَئِنَّكُم',
        'بزيادة همزة استفهام مع تحقيق الهمزتين بلا إدخال',
        'نكم',
      ),
      VariantKind.farsh,
    );
  });

  test(
    'fi hi muhānan has a kasra without silah for every differing riwaya',
    () async {
      final variants = await VariantRepository.discover();
      await variants.ensureLoaded(variants.available);
      final readers = variants.available.difference({'bazzi', 'qunbul'});
      for (final id in readers) {
        final reading = variants.at([id], 25, 69, 6).single;
        expect(reading.text, 'فِيهِ', reason: id);
        expect(reading.shownDescription, contains('بلا صلة'), reason: id);
        expect(
          reading.shownDescription,
          isNot(contains('إسكان الهاء')),
          reason: id,
        );
      }
      expect(variants.at(['bazzi', 'qunbul'], 25, 69, 6), isEmpty);
    },
  );

  test(
    'page 399 shows mawadda tanween and iqlab in the farsh margin',
    () async {
      const readers = {
        'qalun',
        'warsh',
        'hisham',
        'ibn_dhakwan',
        'shubah',
        'ibn_wardan',
        'ibn_jammaz',
        'ishaq',
        'idris',
      };
      final variants = await VariantRepository.discover();
      await variants.ensureLoaded(readers);
      for (final id in readers) {
        final reading = variants.at([id], 29, 25, 7).single;
        expect(reading.kind, VariantKind.farsh, reason: id);
        expect(reading.inHamesh, isTrue, reason: id);
        expect(reading.shownDescription, contains('تنوين'), reason: id);
        expect(reading.shownDescription, contains('الإقلاب'), reason: id);
        expect(reading.text, anyOf(contains('ً'), contains('ۢ')), reason: id);
      }
    },
  );

  test(
    'Shubah adds an interrogative hamza at 29:28 as certified farsh',
    () async {
      final variants = await VariantRepository.discover();
      await variants.ensureLoaded(['shubah']);
      final reading = variants.at(['shubah'], 29, 28, 4).single;
      expect(reading.kind, VariantKind.farsh);
      expect(reading.certified, isTrue);
      expect(reading.inHamesh, isTrue);
      expect(reading.isUsul, isFalse);
      expect(reading.shownDescription, contains('زيادة همزة استفهام'));
    },
  );
}
