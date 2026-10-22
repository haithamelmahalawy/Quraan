import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qiraat_mushaf/data/kharouf.dart';
import 'package:qiraat_mushaf/data/mutashabihat_repository.dart';
import 'package:qiraat_mushaf/data/quran_repository.dart';
import 'package:qiraat_mushaf/data/quranpedia_qiraat.dart';
import 'package:qiraat_mushaf/data/variant_repository.dart';
import 'package:qiraat_mushaf/models/quran.dart';
import 'package:qiraat_mushaf/state/reader_settings.dart';
import 'package:qiraat_mushaf/ui/mushaf_page.dart';
import 'package:qiraat_mushaf/ui/theme.dart';

import '../tool/build_data.dart' as data;
import '../tool/build_kharouf.dart' as book_data;
import '../tool/correct_reviewed_farsh.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository quran;
  late MutashabihatRepository mutashabihat;
  late VariantRepository shubah;
  setUpAll(() async {
    quran = await QuranRepository.load();
    mutashabihat = await MutashabihatRepository.load();
    shubah = await VariantRepository.discover();
    await shubah.ensureLoaded(['shubah']);
    await (FontLoader(
      'Hafs',
    )..addFont(rootBundle.load('assets/fonts/hafs.18.ttf'))).load();
  });

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

  test('a named waqf note restricts only the readers it actually covers', () {
    final group = book_data.parseReaders([
      'ابن كثير',
      'أبو عمرو',
      'ابن عامر',
      'شعبة',
      'يعقوب',
    ]);
    const how = 'ووقف هشام هنا كما وقف على «يستهزئ» ص ٣';
    final (own, notes) = book_data.splitHow(how);
    expect(
      book_data.readingStopOnly(group, 'ترجىءُ', how, own, notes),
      isFalse,
    );
    final hamza = book_data.parseReaders(['حمزة']);
    const stopping = 'وقف حمزة بالنقل';
    final (ownStop, stopNotes) = book_data.splitHow(stopping);
    expect(
      book_data.readingStopOnly(hamza, '', stopping, ownStop, stopNotes),
      isTrue,
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

  test(
    'nimatan keeps the sakin ayn and the feminine tanween, not a sakin ha',
    () {
      const description = 'بإسكان العين وإبدال الهاء تاء مربوطة منونة بالفتح';
      expect(data.describe('نِعَمَهُۥ', 'نِعۡمَةٗ'), description);
      expect(data.classify('نِعَمَهُۥ', 'نِعۡمَةٗ'), 'f');
      final v = shubah.at(['shubah'], 31, 20, 14).single;
      expect(quran.pageOf(31, 20), 413);
      expect(v.text, contains('عۡمَة'));
      expect(v.shownDescription, description);
      expect(v.shownDescription, isNot(contains('إسكان الهاء')));
      expect(v.kind, VariantKind.farsh);
      expect(v.inHamesh, isTrue);
    },
  );

  test(
    'turjii becomes turjiu as lexical farsh and is not limited to stopping',
    () async {
      expect(data.classify('تُرۡجِي', 'تُرۡجِئُ'), 'f');
      expect(data.describe('تُرۡجِي', 'تُرۡجِئُ'), 'بإبدال الياء همزة مضمومة');
      final v = shubah.at(['shubah'], 33, 51, 0).single;
      expect(quran.pageOf(33, 51), 425);
      expect(v.text, 'تُرۡجِئُ');
      expect(v.shownDescription, 'بإبدال الياء همزة مضمومة');
      expect(v.certified, isTrue);
      expect(v.kind, VariantKind.farsh);
      expect(v.isUsul, isFalse);
      expect(v.inHamesh, isTrue);
      expect(v.stopOnly, isFalse);
      final source = (await Kharouf.load()).at(33, 51, 0).single;
      final reading = source.readings.firstWhere(
        (r) => r.riwayat.contains('shubah'),
      );
      expect(reading.stopOnly, isFalse);
      expect(reading.notes.expand((n) => n.$2), contains('hisham'));
      expect(reading.notes.expand((n) => n.$2), isNot(contains('shubah')));
    },
  );

  test(
    'the alif of al-rasula and al-sabila is retained in wasl and waqf as farsh',
    () async {
      final book = await Kharouf.load();
      for (final (a, w, word) in [
        (10, 15, 'ٱلظُّنُونَا'),
        (66, 10, 'ٱلرَّسُولَا'),
        (67, 7, 'ٱلسَّبِيلَا'),
      ]) {
        final v = shubah.at(['shubah'], 33, a, w).single;
        expect(v.text, word);
        expect(v.shownDescription, 'بإثبات الألف وصلاً ووقفاً');
        expect(v.kind, VariantKind.farsh);
        expect(v.isUsul, isFalse);
        expect(v.inHamesh, isTrue);
        expect(v.certified, isTrue);
        expect(v.stopOnly, isFalse);
        final note = book.at(33, a, w).singleWhere((e) => e.section == 'farsh');
        expect(note.verses, isNotEmpty);
        final reading = note.readings.firstWhere(
          (r) => r.riwayat.contains('shubah'),
        );
        expect(reading.how, 'بإثبات الألف وصلاً ووقفاً');
        expect(reading.stopOnly, isFalse);
        if (a != 10) {
          expect(quran.pageOf(33, a), 427);
          expect(reading.text, word);
          expect(reading.text, isNot(contains('ظن')));
        }
      }
    },
  );

  test('reviewed data correction is repeatable and preserves the existing first three fixes', () {
    final base =
        jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map;
    final file = jsonDecode(
      File('assets/data/qiraat/shubah.json').readAsStringSync(),
    ) as Map;
    final rows = file['variants'] as List;
    final before = jsonEncode(rows);
    correctReviewedFarsh('shubah', base, rows);
    expect(jsonEncode(rows), before);
    for (final (s, a, w) in [
      (25, 69, 6),
      (29, 25, 7),
      (29, 28, 4),
      (31, 20, 14),
      (33, 51, 0),
      (33, 66, 10),
      (33, 67, 7),
    ]) {
      expect(
        rows.where((r) => r[0] == s && r[1] == a && r[2] == w),
        hasLength(1),
      );
    }
  });

  testWidgets('reviewed Shubah readings appear in the actual page margin', (
    t,
  ) async {
    t.view.physicalSize = const Size(1080, 2000);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final theme = buildTheme(MushafPalette.light);
    for (final (page, description, count) in [
      (413, 'بإسكان العين وإبدال الهاء تاء مربوطة منونة بالفتح', 1),
      (425, 'بإبدال الياء همزة مضمومة', 1),
      (427, 'بإثبات الألف وصلاً ووقفاً', 2),
    ]) {
      await t.pumpWidget(
        MaterialApp(
          theme: theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'Hafs'),
          ),
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: MushafPage(
                page: page,
                quran: quran,
                variants: shubah,
                mutashabihat: mutashabihat,
                settings: ReaderSettings.memory(selected: {'shubah'}),
                onWordTap: (_, _) {},
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.textContaining(description, findRichText: true),
        findsNWidgets(count),
      );
      expect(t.takeException(), isNull);
    }
  });
}
